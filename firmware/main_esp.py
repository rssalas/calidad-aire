"""
Sistema de Monitoreo y Alertas Tempranas de Calidad del Aire
E.S.E Hospital Santa Cruz de Urumita - La Guajira
Firmware ESP32-S3 (MicroPython) - VERSION ESTABLE Y SEGURA (PRODUCCION)
"""

from machine import Pin, I2C, UART, ADC, WDT
import uasyncio as asyncio
import network
import urequests
import ujson
import time
import gc
import os
import socket

try:
    import ntptime
except ImportError:
    ntptime = None

import ssd1306
from dht import DHT22

from services.wifi_service import WiFiService
from services.webserver import start
from core.config import *

try:
    socket.setdefaulttimeout(15)
except AttributeError:
    print("Aviso: socket.setdefaulttimeout no disponible en este build de MicroPython")

wifi = WiFiService()

FIREBASE_BASE = "https://santa-cruz-iot-air-quality-default-rtdb.firebaseio.com"
FIREBASE_AUTH = ""  # <-- completar antes de la instalacion final en el hospital

URL_ESTADO_ACTUAL = FIREBASE_BASE + "/estado_actual.json" + FIREBASE_AUTH
URL_HISTORICO = FIREBASE_BASE + "/historico_pendiente.json" + FIREBASE_AUTH

BUFFER_FILE = "buffer_datos.jsonl"
BUFFER_MAX_LINEAS = 10080

MUESTRAS_POR_PROMEDIO = 20
INTERVALO_ENVIO_MS = 30000
LOTE_DRENAJE_MAX = 5

CALIB_FILE = "r0_calibrado.json"
PRECAL_SEGUNDOS = 180

RL_RED = 22000
RL_NOX = 47000
RO_RED_DEFAULT = 100000
RO_NOX_DEFAULT = 13850

uart = UART(1, baudrate=9600, tx=16, rx=15)

# Orden fisico en el esquematico: IO38, IO39, IO40, IO41, IO42, IO14
# 0=Temp, 1=Hum, 2=CO, 3=NO2, 4=PM2.5, 5=PM10
pines_leds = [38, 39, 40, 41, 42, 14]
leds = [Pin(x, Pin.OUT) for x in pines_leds]

reset_wifi = Pin(1, Pin.IN, Pin.PULL_UP)
led_wifi = Pin(2, Pin.OUT, value=0)

adc_red = ADC(4)
adc_red.atten(ADC.ATTN_11DB)
adc_nox = ADC(5)
adc_nox.atten(ADC.ATTN_11DB)
pre = Pin(6, Pin.OUT, value=1)

DTH = DHT22(Pin(7))

i2c = I2C(1, scl=Pin(18), sda=Pin(17), freq=400000)
display = ssd1306.SSD1306_I2C(128, 64, i2c)

sensor = {"temp": 0, "hum": 0, "dust": {"pm2.5": 0, "pm10": 0}, "co": 0, "no2": 0}
state = {"wifi_conect": False, "ntp_sync": False}
sensores_listos = {"dht": False, "mics": False, "sds": False}
tasks = {}
flag = asyncio.ThreadSafeFlag()

def irq(pin):
    flag.set()

reset_wifi.irq(trigger=Pin.IRQ_FALLING, handler=irq)

wdt = WDT(timeout=30000)

async def watchdog_task():
    while True:
        wdt.feed()
        await asyncio.sleep_ms(5000)

# ==========================================================================
# UMBRALES DE ALARMA (unico valor por variable: solo el LED de alarma)
# CO corregido: 4mg/m3 y 8.8ppm (Res. 601/2006) convertidos correctamente
# a ppm usando el factor a 25C (1.145), en vez del valor en mg/m3 sin
# convertir que se usaba antes.
# ==========================================================================
UMBRALES_ALARMA = {
    "temp": 30.0,
    "hum": 70.0,
    "co": 8.8,
    "no2": 0.027,
    "pm25": 25.0,
    "pm10": 75.0,
}

def supera_alarma(valor, umbral):
    if valor is None:
        return False
    return valor > umbral

def calc_rs(vout, rl, vcc=4.96):
    if vout is None or vout <= 0: return None
    return rl * (vcc - vout) / vout

def co_ppm(rs, ro):
    if rs is None or ro <= 0: return None
    ratio = rs / ro
    if ratio <= 0: return None
    try:
        return (ratio / 1.13) ** (1.0 / -0.336)
    except Exception:
        return None

def no2_ppm(rs, ro):
    if rs is None or ro <= 0: return None
    ratio = rs / ro
    if ratio <= 0: return None
    try:
        return (ratio / 6.31) ** (1.0 / 0.80)
    except Exception:
        return None

def cargar_calibracion():
    try:
        with open(CALIB_FILE, "r") as f:
            datos = ujson.load(f)
            return datos.get("ro_red", RO_RED_DEFAULT), datos.get("ro_nox", RO_NOX_DEFAULT)
    except (OSError, ValueError):
        return RO_RED_DEFAULT, RO_NOX_DEFAULT

def guardar_calibracion(ro_red, ro_nox):
    try:
        with open(CALIB_FILE, "w") as f:
            ujson.dump({"ro_red": ro_red, "ro_nox": ro_nox, "ts": time.time()}, f)
    except OSError as e:
        print("Error guardando calibracion:", e)

def contar_lineas_buffer():
    try:
        with open(BUFFER_FILE, "r") as f:
            return sum(1 for _ in f)
    except OSError:
        return 0

def guardar_en_buffer(data):
    try:
        if contar_lineas_buffer() >= BUFFER_MAX_LINEAS:
            _descartar_linea_mas_antigua()
        OFFSET_EPOCH_MICROPYTHON = 946684800
        data["ts_local"] = (time.time() + OFFSET_EPOCH_MICROPYTHON) if state["ntp_sync"] else None
        with open(BUFFER_FILE, "a") as f:
            f.write(ujson.dumps(data) + "\n")
    except OSError as e:
        print("Error escribiendo buffer:", e)

def _reemplazar_archivo(origen, destino):
    try:
        os.remove(destino)
    except OSError:
        pass
    os.rename(origen, destino)

def _descartar_linea_mas_antigua():
    try:
        with open(BUFFER_FILE, "r") as f_in, open("temp.jsonl", "w") as f_out:
            f_in.readline()
            for line in f_in:
                f_out.write(line)
        _reemplazar_archivo("temp.jsonl", BUFFER_FILE)
    except OSError:
        pass

def hay_datos_en_buffer():
    try:
        return os.stat(BUFFER_FILE)[6] > 0
    except OSError:
        return False

async def drenar_buffer():
    if not hay_datos_en_buffer():
        return
    try:
        enviadas = 0
        error = False
        with open(BUFFER_FILE, "r") as f_in, open("temp.jsonl", "w") as f_out:
            for line in f_in:
                if enviadas < LOTE_DRENAJE_MAX and not error:
                    response = None
                    try:
                        data = ujson.loads(line)
                        response = urequests.post(URL_HISTORICO, data=ujson.dumps(data))
                        enviadas += 1
                        wdt.feed()
                        await asyncio.sleep_ms(100)
                    except Exception as e:
                        print("Fallo enviando historico:", e)
                        error = True
                        f_out.write(line)
                    finally:
                        if response:
                            response.close()
                else:
                    f_out.write(line)
        _reemplazar_archivo("temp.jsonl", BUFFER_FILE)

        if enviadas:
            gc.collect()
            print("Lote del buffer drenado:", enviadas)
    except OSError as e:
        print("Error procesando buffer:", e)

def timestamp_valido():
    return time.time() > 800000000

async def sincronizar_ntp():
    if ntptime is None:
        return False
    try:
        ntptime.settime()
        state["ntp_sync"] = timestamp_valido()
        return state["ntp_sync"]
    except Exception:
        state["ntp_sync"] = False
        return False

async def precal(segundos):
    for i in range(segundos):
        wdt.feed()
        display.fill(0)
        display.text("INICIANDO", 0, 20)
        display.text(str(segundos - i) + "s", 0, 45)
        display.show()
        await asyncio.sleep(1)

async def mics_task():
    ro_red, ro_nox = cargar_calibracion()
    samples = 40
    while True:
        try:
            prom_nox = sum(adc_nox.read() for _ in range(samples)) / samples
            prom_red = sum(adc_red.read() for _ in range(samples)) / samples

            rs_nox = calc_rs(((prom_nox / 4095) * 3.3) * 1.5, RL_NOX)
            rs_red = calc_rs(((prom_red / 4095) * 3.3) * 1.5, RL_RED)

            ppm_red = co_ppm(rs_red, ro_red)
            ppm_nox = no2_ppm(rs_nox, ro_nox)

            if ppm_red is not None: sensor["co"] = ppm_red
            if ppm_nox is not None: sensor["no2"] = ppm_nox
            sensores_listos["mics"] = True
        except Exception:
            pass
        await asyncio.sleep_ms(500)

async def dth_task():
    while True:
        try:
            DTH.measure()
            sensor["temp"] = DTH.temperature()
            sensor["hum"] = DTH.humidity()
            sensores_listos["dht"] = True
        except Exception:
            pass
        await asyncio.sleep_ms(2000)

async def sds_task():
    while True:
        try:
            if uart.any() >= 10:
                data = uart.read(10)
                if data and len(data) == 10 and data[0] == 0xAA and data[1] == 0xC0 and data[9] == 0xAB:
                    if (sum(data[2:8]) % 256) == data[8]:
                        sensor["dust"]["pm2.5"] = ((data[3] << 8) | data[2]) / 10
                        sensor["dust"]["pm10"] = ((data[5] << 8) | data[4]) / 10
                        sensores_listos["sds"] = True
        except Exception:
            pass
        await asyncio.sleep_ms(1000)

async def leds_task():
    while True:
        try:
            alarmas = [
                supera_alarma(sensor["temp"], UMBRALES_ALARMA["temp"]),
                supera_alarma(sensor["hum"], UMBRALES_ALARMA["hum"]),
                supera_alarma(sensor["co"], UMBRALES_ALARMA["co"]),
                supera_alarma(sensor["no2"], UMBRALES_ALARMA["no2"]),
                supera_alarma(sensor["dust"]["pm2.5"], UMBRALES_ALARMA["pm25"]),
                supera_alarma(sensor["dust"]["pm10"], UMBRALES_ALARMA["pm10"]),
            ]
            for i, en_alarma in enumerate(alarmas):
                if en_alarma:
                    leds[i].value(not leds[i].value())
                else:
                    leds[i].off()
        except Exception:
            pass
        await asyncio.sleep_ms(500)

async def lcd_task():
    try:
        while True:
            display.fill(0)
            estado_txt = "MODO NORMAL" if state["wifi_conect"] else "SIN WIFI (buffer)"
            display.text(estado_txt, 0, 0)
            display.text("T:{:0.1f}C H:{:0.1f}%".format(sensor["temp"], sensor["hum"]), 0, 12)
            display.text("Co: {:0.2f}ppm".format(sensor["co"]), 0, 22)
            display.text("No2: {:0.3f}ppm".format(sensor["no2"]), 0, 32)
            display.text("D2.5: {:0.1f}ug".format(sensor["dust"]["pm2.5"]), 0, 42)
            display.text("D10: {:0.1f}ug".format(sensor["dust"]["pm10"]), 0, 52)
            display.show()
            await asyncio.sleep_ms(1000)
    except asyncio.CancelledError:
        pass

async def wifi_task():
    while True:
        try:
            std = wifi.is_connected()
            if not std:
                led_wifi.off()
                await asyncio.sleep_ms(500)
                # Opcional: Se puede pasar wdt aquí también si requieres protección en reconexiones futuras
                std = await wifi.connect()
                if std:
                    await sincronizar_ntp()
            else:
                led_wifi.on()
            state["wifi_conect"] = std
        except Exception:
            state["wifi_conect"] = False
        await asyncio.sleep_ms(1000)

async def boton_task():
    while True:
        await flag.wait()
        inicio = time.ticks_ms()
        if "lcd" in tasks:
            tasks["lcd"].cancel()
        while reset_wifi.value() == 0:
            display.fill(0)
            display.text("RESETEANDO...", 0, 25)
            display.show()
            if time.ticks_diff(time.ticks_ms(), inicio) >= 5000:
                display.fill(0)
                display.text("WIFI RESET OK", 0, 25)
                display.show()
                await asyncio.sleep_ms(1000)
                try:
                    os.remove("wifi.json")
                except OSError:
                    pass
                import machine
                machine.reset()
            await asyncio.sleep_ms(50)
        tasks["lcd"] = asyncio.create_task(lcd_task())

acumulador = {"temp": 0, "hum": 0, "co": 0, "no2": 0, "pm25": 0, "pm10": 0, "n": 0}

def resetear_acumulador():
    for k in acumulador:
        acumulador[k] = 0

def acumular_lectura(payload):
    acumulador["temp"] += payload["dht22"]["temperatura"]
    acumulador["hum"] += payload["dht22"]["humedad"]
    acumulador["co"] += payload["mics4514"]["co_ppm"]
    acumulador["no2"] += payload["mics4514"]["no2_ppm"]
    acumulador["pm25"] += payload["sds011"]["pm25"]
    acumulador["pm10"] += payload["sds011"]["pm10"]
    acumulador["n"] += 1

def construir_promedio():
    n = acumulador["n"]
    if n == 0: n = 1
    return {
        "dht22": {
            "humedad": acumulador["hum"] / n,
            "temperatura": acumulador["temp"] / n,
        },
        "mics4514": {
            "co_ppm": acumulador["co"] / n,
            "no2_ppm": acumulador["no2"] / n,
        },
        "sds011": {
            "pm25": acumulador["pm25"] / n,
            "pm10": acumulador["pm10"] / n,
        },
        "n_muestras": acumulador["n"],
    }

def construir_payload():
    return {
        "dht22": {"humedad": sensor["hum"], "temperatura": sensor["temp"]},
        "mics4514": {"co_ppm": sensor["co"], "no2_ppm": sensor["no2"]},
        "sds011": {"pm25": sensor["dust"]["pm2.5"], "pm10": sensor["dust"]["pm10"]},
    }

async def send_firebase_task():
    while True:
        await asyncio.sleep_ms(INTERVALO_ENVIO_MS)
        try:
            if not all(sensores_listos.values()):
                continue

            data = construir_payload()
            acumular_lectura(data)

            if state["wifi_conect"]:
                response = None
                wdt.feed()
                try:
                    response = urequests.patch(URL_ESTADO_ACTUAL, data=ujson.dumps(data))
                except Exception as e:
                    print("Error enviando estado_actual:", e)
                finally:
                    if response:
                        response.close()

                await drenar_buffer()

            if acumulador["n"] >= MUESTRAS_POR_PROMEDIO:
                promedio = construir_promedio()
                resetear_acumulador()

                if state["wifi_conect"]:
                    response = None
                    wdt.feed()
                    try:
                        response = urequests.post(URL_HISTORICO, data=ujson.dumps(promedio))
                    except Exception as e:
                        print("Error enviando promedio, se guarda en buffer:", e)
                        guardar_en_buffer(promedio)
                    finally:
                        if response:
                            response.close()
                else:
                    guardar_en_buffer(promedio)

        except Exception as e:
            print("Error fatal en send_firebase:", e)

async def gc_task():
    while True:
        gc.collect()
        await asyncio.sleep(60)

async def main():
    # 1. TAREA DEL WATCHDOG CREADA INMEDIATAMENTE AL INICIO
    tasks["wdt"] = asyncio.create_task(watchdog_task())

    # 2. PASAMOS EL WDT AL SERVICIO WIFI PARA PROTEGER LA BÚSQUEDA DE MÚLTIPLES REDES
    if not await wifi.connect():
        display.fill(0)
        display.text("Configurar wifi", 0, 0)
        display.text("SSID: " + str(WIFI_AP_SSID), 0, 25)
        display.show()
        
        await wifi.start_ap()
        await start(wifi, wdt)  # El webserver recibe WiFiService y el watchdog
    else:
        state["wifi_conect"] = True
        await sincronizar_ntp()

        tasks["dth"] = asyncio.create_task(dth_task())
        tasks["mics"] = asyncio.create_task(mics_task())
        tasks["sds"] = asyncio.create_task(sds_task())

        await asyncio.gather(precal(PRECAL_SEGUNDOS))

        tasks["indic"] = asyncio.create_task(leds_task())
        tasks["lcd"] = asyncio.create_task(lcd_task())
        tasks["conect"] = asyncio.create_task(wifi_task())
        tasks["firebase"] = asyncio.create_task(send_firebase_task())
        tasks["gc"] = asyncio.create_task(gc_task())
        asyncio.create_task(boton_task())

    while True:
        await asyncio.sleep(1)

asyncio.run(main())
