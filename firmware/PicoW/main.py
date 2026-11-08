# Raspberry Pi Pico W (MicroPython) keychain firmware.
# Sends button/motion/touch to the iPhone over BLE; draws the ASCII face it receives on a 2.42" I2C OLED.
#
# Setup:
#   1. Flash the MicroPython firmware for **Pico W** (plain Pico has no Bluetooth).
#   2. mpremote mip install aioble
#      mpremote mip install ssd1306
#   3. Copy this file to the board as main.py.
#
# Wiring (I2C0): OLED VCC->3V3(OUT), GND->GND, SDA->GP4, SCL->GP5.  Button GP14 -> GND.  Touch module OUT -> GP15.
# 2.42" boards often ship set for SPI: check the back solder bridges/resistors and set I2C (address 0x3C or 0x3D).
# Controller is SSD1309. It is largely SSD1306-compatible, so the stock ssd1306 driver should work
# (SSD1309 just ignores the SSD1306 charge-pump command). If the module has a RES/RST pin, it must be
# held high or pulsed at startup - see RES_PIN below.

import asyncio
import struct
import time
import bluetooth
import framebuf
from reminder_icons import ICONS
import aioble
import ssd1306
from machine import Pin, I2C

SERVICE_UUID = bluetooth.UUID(0xFFE0)
SENSOR_UUID = bluetooth.UUID(0xFFE1)   # notify -> phone  (matches BLEManager.sensorCharUUID)
FACE_UUID = bluetooth.UUID(0xFFE2)     # write  <- phone  (matches BLEManager.faceCharUUID)

button = Pin(14, Pin.IN, Pin.PULL_UP)
touch = Pin(15, Pin.IN)
RES_PIN = None   # e.g. 6 to wire OLED RES -> GP6 (pulsed low->high at boot). None if RES is tied to 3V3 / not present.
if RES_PIN is not None:
    res = Pin(RES_PIN, Pin.OUT)
    res.value(1); time.sleep_ms(10); res.value(0); time.sleep_ms(20); res.value(1); time.sleep_ms(20)

i2c = I2C(0, sda=Pin(4), scl=Pin(5), freq=400_000)
found = i2c.scan()   # 2.42" modules are usually 0x3C or 0x3D
print("I2C devices:", [hex(a) for a in found])
oled = ssd1306.SSD1306_I2C(128, 64, i2c, addr=0x3C if 0x3C in found or not found else found[0])
oled.contrast(80)   # dimmer = less power

rows = ["  .-----.", " | o   o |", " |   -   |", " |  ___  |", "  '-----'"]
dirty = True
reminder_until = None


def read_motion():
    # TODO: IMU (MPU6050/LIS3DH/...). Accelerometers can't give true velocity (integration drifts);
    # return smoothed motion magnitude (|accel| - 1g). The app treats > 2.0 as "fast".
    return 0.0


svc = aioble.Service(SERVICE_UUID)
sensor = aioble.Characteristic(svc, SENSOR_UUID, read=True, notify=True)
face_char = aioble.Characteristic(svc, FACE_UUID, write=True, capture=True)
aioble.register_services(svc)


def draw():
    oled.fill(0)
    for i, r in enumerate(rows):
        oled.text(r, 4, i * 12 + 2)   # 8x8 font: 15 cols = 120px wide; 12px row pitch
    oled.show()


async def face_task():
    # Each write is [row index][ASCII text]. Five writes make one face.
    global dirty, reminder_until
    while True:
        _conn, data = await face_char.written()
        if data and data[0] == 0xFF:
            icon = ICONS.get(bytes(data[1:]))
            if icon is not None:
                oled.fill(0)
                oled.blit(framebuf.FrameBuffer(bytearray(icon), 64, 64,
                                              framebuf.MONO_HLSB), 32, 0)
                oled.show()
                reminder_until = time.ticks_add(time.ticks_ms(), 5000)
        elif data and data[0] < 5:
            rows[data[0]] = bytes(data[1:]).decode("ascii", "ignore")
            dirty = True


async def display_task():
    global dirty, reminder_until
    while True:
        if reminder_until is not None and time.ticks_diff(time.ticks_ms(), reminder_until) >= 0:
            reminder_until = None
            dirty = True
        if dirty and reminder_until is None:
            dirty = False
            draw()
        await asyncio.sleep_ms(30)


async def sensor_task(conn):
    # Packet = [flags: bit0 button][velocity Int16 LE x100][touch UInt8]  (matches DemoDecoder)
    while conn.is_connected():
        flags = 1 if button.value() == 0 else 0
        vel = int(read_motion() * 100)
        t = 255 if touch.value() else 0
        sensor.notify(conn, struct.pack("<BhB", flags, vel, t))
        await asyncio.sleep_ms(100)   # 10 Hz


async def peripheral_task():
    while True:
        async with await aioble.advertise(250_000, name="FaceKeychain", services=[SERVICE_UUID]) as conn:
            await sensor_task(conn)   # returns on disconnect, then we advertise again


async def main():
    await asyncio.gather(peripheral_task(), face_task(), display_task())


asyncio.run(main())
