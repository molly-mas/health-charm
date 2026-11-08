import bluetooth
import time
import urandom
import framebuf
import machine
from machine import Pin, I2C
from micropython import const
 
# =============================================================================
# 1. HARDWARE PINOUT CONFIGURATION
# =============================================================================
 
# I2C LCD Configuration (PCF8574 backpack)
I2C_ID = 0
I2C_SDA_PIN = 0          # GP0 (Pin 1)
I2C_SCL_PIN = 1          # GP1 (Pin 2)
I2C_FREQ = 400_000
LCD_I2C_ADDR = 0x27      # Common addresses: 0x27 or 0x3F
LCD_COLS = 16
LCD_ROWS = 2
 
# Buttons (Active-Low with internal pull-ups: Pin to Button to GND)
BTN_A_PIN = 14           # GP14 (Pin 19) -> [A] YES
BTN_B_PIN = 15           # GP15 (Pin 20) -> [B] NO
DEBOUNCE_MS = 30
 
# Capacitive Touch Sensor (TTP223 Active-High)
TOUCH_PIN = 16           # GP16 (Pin 21)
TOUCH_MIN_MS = 60        # Min duration for a valid tap
TOUCH_HOLD_MS = 1200     # Threshold for a long hold reaction
 
# Actuator: Vibration Motor Driver
VIB_PIN = 17             # GP17 (Pin 22)
 
# Digital Shake Sensor (SW-420 or ball-switch pulse counter)
SHAKE_PIN = 18           # GP18 (Pin 24)
SHAKE_WINDOW_MS = 500    # Rolling window to evaluate pulses
SHAKE_HEAVY_PULSES = 8   # Pulses in window for heavy shake
SHAKE_LIGHT_PULSES = 3   # Pulses in window for light shake
 
# Timers
LOCAL_PROMPT_INTERVAL_MS = 300_000  # Fallback prompt every 5 minutes if app is silent
REACTION_DISPLAY_MS = 2500          # Reaction display hold time
IDLE_BLINK_INTERVAL_MS = 4000        # Time between automatic idle blinks
IDLE_BLINK_DURATION_MS = 180         # How long the blink face is shown
SHAKE_IRQ_DEBOUNCE_MS = 8            # Ignore switch chatter between shake pulses
 
 
# =============================================================================
# 2. ASCII FACES & CONTENT PROVIDER
# =============================================================================
 
FACES = {
    # Idle States
    "normal":           "( ^_^ )",
    "blink":            "( -_- )",
 
    # Prompt responses
    "btn_a_happy":      "\\(^o^)/",
    "btn_b_thumbs_up":  "b( ^_^ )d",
 
    # Touch interactions
    "touch_short":      "( ^3^ )",
    "touch_long":       "( >w< )",
 
    # Shake reactions
    "shaken_light":     "( o_O )",
    "shaken_heavy":     "( X_X )",
}
 
DEFAULT_PROMPTS = [
    {
        "icon": "eat",
        "line1": "Eat some Food?",
        "line2": "[A]Yes    [B]No ",
        "face_a": "btn_a_happy",
        "face_b": "btn_b_thumbs_up",
    },
    {
        "icon": "water",
        "line1": "Drink water?",
        "line2": "[A]Yes    [B]Later",
        "face_a": "( ^o^ )  Glug glug",
        "face_b": "( ~_~ )  Maybe l8r",
    },
    {
        "icon": "walk",
        "line1": "Take a walk?",
        "line2": "[A]Sure   [B]Nope",
        "face_a": "d( ^o^ )b  Lets go",
        "face_b": "( ~_~ )  Next time",
    },
    {
        "icon": "chat",
        "line1": "Want to chat?",
        "line2": "[A]Yes    [B]Later",
        "face_a": "( ^_^ )  Lets talk",
        "face_b": "( -_- )  Ok, later",
    },
    {
        "icon": "custom",
        "line1": "Take a breath?",
        "line2": "[A]Yes    [B]Nah",
        "face_a": "( *^_^* )  In..Out..",
        "face_b": "( ~_~ )  Maybe l8r",
    },
]
 
 
class ContentProvider:
    """Manages ASCII face rendering format and prompt queue."""
    def __init__(self, faces_dict, prompts_list):
        self.faces = faces_dict
        self.prompts = prompts_list
 
    def get_face(self, key_or_literal):
        raw = self.faces.get(key_or_literal, key_or_literal)
        if isinstance(raw, tuple):
            return raw[0][:16], raw[1][:16]
        if "  " in raw:
            parts = raw.split("  ", 1)
            return parts[0][:16].center(16), parts[1][:16].center(16)
        return raw[:16].center(16), raw[16:32].center(16)
 
    def get_random_prompt(self):
        idx = urandom.getrandbits(8) % len(self.prompts)
        return self.prompts[idx]
 
 
# =============================================================================
# 2A. 64x64 ICON BITMAPS (converted from PNG to MONO_VLSB for the OLED)
# =============================================================================
 
ICON_W = 64
ICON_H = 64
 
ICON_HEX = {
    "eat": (
        "00000000000000000000000080808000000000000080808000000000000080808080000000000000000000000000000000808080000000000000000000000000"
        "0000000000000000000000ffffffffff00000000ffffffffff0000000000ffffffff0000000000000080f0f8fcfefeffffffffffff0000000000000000000000"
        "0000000000000000000000ffffffffff80808080ffffffffff8080808080ffffffff00000000000000ffffffffffffffffffffffff0000000000000000000000"
        "0000000000000000000000030f1f3f7f7fffffffffffffffffffffffff7f3f3f0f07000000000000007fffffffffffffffffffffff0000000000000000000000"
        "0000000000000000000000000000000000000000ffffffffff0000000000000000000000000000000000010303070707ffffffffff0000000000000000000000"
        "0000000000000000000000000000000000000000ffffffffff0000000000000000000000000000000000000000000000ffffffffff0000000000000000000000"
        "00000000000000000000000000000000000000000f1f1f1f0f00000000000000000000000000000000000000000000000f1f1f1f0f0000000000000000000000"
        "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    ),
    "water": (
        "00000000000000000000000000000000000000000000000000000000000080808080000000000000000000000000000000000000000000000000000000000000"
        "0000000000000000000000000000000000000000000080c0e0f0f8fcfefffffffffffffefcf8f0e0c08000000000000000000000000000000000000000000000"
        "0000000000000000000000000000000080e0f0f8fefffffffffffffffffffffffffffffffffffffffffffffef8f0e08000000000000000000000000000000000"
        "0000000000000000000000000080f8fefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffef88000000000000000000000000000"
        "0000000000000000000000000007ffffffffffffff8303031f7fffffffffffffffffffffffffffffffffffffffffffffffff0700000000000000000000000000"
        "000000000000000000000000000000030f1f7ffffffffffcf8f8f0f0e1e1e3e3e3e3ffffffffffffffffffffff7f1f0f03000000000000000000000000000000"
        "0000000000000000000000000000000000000000000103030707070f0f0f0f0f0f0f0f0f0f070707030301000000000000000000000000000000000000000000"
        "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    ),
    "walk": (
        "000000000000000000000000000000000000000000000000000000000000000080c0c0c0c0c08000000000000000000000000000000000000000000000000000"
        "000000000000000000000000000000000000000000000000000000000000000f3f3f7f7f7f3f3f0f000000000000000000000000000000000000000000000000"
        "000000000000000000000000000000000000c0e0f0f0f8f8f87c7cfefefffffffffffefcf8e0c000000000000000000000000000000000000000000000000000"
        "0000000000000000000000000000000000007fffffff7f0000c0feffffffffffffff7f07070f1f3f3e7c7cf8f8f8f07000000000000000000000000000000000"
        "000000000000000000000000000000000000000000000000f8ffffffff1f3f7ffffffcf8f0e0c000000000000000000000000000000000000000000000000000"
        "00000000000000000000000000000000000000000000e0ffffffff3f010000000001ffffffffff00000000000000000000000000000000000000000000000000"
        "0000000000000000000000000000000000000000007cffff7f3f03000000000000003f7fff7f7f00000000000000000000000000000000000000000000000000"
        "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    ),
    "chat": (
        "00000000000000000000008080808080808080808080808080808080808080808080808080808080808080808080808080808080800000000000000000000000"
        "000000000000000000fefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe000000000000000000"
        "000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000"
        "000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000"
        "000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000"
        "000000000000000000ffffffffffff7f3f1f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0703000000000000000000"
        "0000000000000000001f0f0703010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    ),
    "custom": (
        "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        "00000000000000000000000000000000000000000000000000000000c0c0c0c0c0c0c00000000000000000000000000000000000000000000000000000000000"
        "00000000000000000000000000000000000000000000000000000000ffffffffffffff0000000000000000000000000000000000000000000000000000000000"
        "0000000000000000000000000000000000000000000000000000000000ffffffffffff0000000000000000000000000000000000000000000000000000000000"
        "000000000000000000000000000000000000000000000000000000000007ffffffff000000000000000000000000000000000000000000000000000000000000"
        "0000000000000000000000000000000000000000000000000000000000fcfcfcfcfcfc0000000000000000000000000000000000000000000000000000000000"
        "00000000000000000000000000000000000000000000000000000000000101010101010000000000000000000000000000000000000000000000000000000000"
        "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    ),
}
 
ICONS = {k: bytearray(bytes.fromhex(v)) for k, v in ICON_HEX.items()}
 
 
# =============================================================================
# 3. BIDIRECTIONAL BLE NORDIC UART SERVICE (NUS)
# =============================================================================
 
_IRQ_CENTRAL_CONNECT = const(1)
_IRQ_CENTRAL_DISCONNECT = const(2)
_IRQ_GATTS_WRITE = const(3)
_FLAG_NOTIFY = const(0x0010)
_FLAG_WRITE = const(0x0008)
 
_UART_UUID = bluetooth.UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
_UART_TX = (bluetooth.UUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E"), _FLAG_NOTIFY)
_UART_RX = (bluetooth.UUID("6E400002-B5A3-F393-E0A9-E50E24DCCA9E"), _FLAG_WRITE)
_UART_SERVICE = (_UART_UUID, (_UART_TX, _UART_RX))
 
 
class BLEUART:
    """Bidirectional BLE UART handler for app communications."""
    def __init__(self, ble, rx_callback, name="Pebble-Pico"):
        self._ble = ble
        self._rx_callback = rx_callback
        self._ble.active(True)
        self._ble.irq(self._irq)
        ((self._handle_tx, self._handle_rx),) = self._ble.gatts_register_services((_UART_SERVICE,))
        self._connections = set()
        self._rx_buffer = bytearray()
        self._advertise(name)
 
    def _irq(self, event, data):
        # Central app connected
        if event == _IRQ_CENTRAL_CONNECT:
            conn_handle, _, _ = data
            self._connections.add(conn_handle)
            print("[BLE] App connected.")
 
        # Central app disconnected
        elif event == _IRQ_CENTRAL_DISCONNECT:
            conn_handle, _, _ = data
            self._connections.remove(conn_handle)
            print("[BLE] App disconnected. Advertising...")
            self._advertise()
 
        # Data received FROM the app (App -> Pico)
        elif event == _IRQ_GATTS_WRITE:
            conn_handle, value_handle = data
            if value_handle == self._handle_rx:
                incoming_bytes = self._ble.gatts_read(self._handle_rx)
                self._rx_buffer.extend(incoming_bytes)
                # Parse newline-delimited command strings
                while b"\n" in self._rx_buffer:
                    line, self._rx_buffer = self._rx_buffer.split(b"\n", 1)
                    clean_cmd = line.decode().strip()
                    if clean_cmd:
                        self._rx_callback(clean_cmd)
 
    def send(self, data: str):
        """Transmits an ASCII string with newline to the connected app (Pico -> App)."""
        msg = (data + "\n").encode()
        for conn_handle in self._connections:
            try:
                self._ble.gatts_notify(conn_handle, self._handle_tx, msg)
            except Exception as e:
                print(f"[BLE TX Error] {e}")
 
    def _advertise(self, name="Pebble-Pico"):
        payload = bytearray()
        payload.extend(bytearray([0x02, 0x01, 0x06]))
        name_bytes = name.encode()
        payload.extend(bytearray([len(name_bytes) + 1, 0x09]) + name_bytes)
        self._ble.gap_advertise(100000, adv_data=payload)
        print(f"[BLE] Advertising as '{name}'...")
 
 
# =============================================================================
# 4. LCD DRIVER (PCF8574 I2C Backpack with Console Mirror Fallback)
# =============================================================================
 
class I2cLcd:
    """
    128x64 monochrome OLED driver.
 
    The class keeps the I2cLcd name and show_lines() interface so the
    rest of emote1.py does not need to change.
    """
 
    def __init__(self, i2c, i2c_addr, num_lines=2, num_columns=16):
        self.i2c = i2c
        self.i2c_addr = i2c_addr
        self.num_lines = num_lines
        self.num_columns = num_columns
        self.width = 128
        self.height = 64
        self.available = True
        self._last_lines = None
 
        devices = self.i2c.scan()
        if self.i2c_addr not in devices:
            if devices:
                self.i2c_addr = devices[0]
            else:
                self.available = False
                print("[OLED] No hardware OLED detected; mirroring text to REPL.")
                return
 
        # OLED framebuffer: one bit per pixel, vertical least-significant bit.
        self.buffer = bytearray(self.width * self.height // 8)
        self.framebuf = framebuf.FrameBuffer(
            self.buffer,
            self.width,
            self.height,
            framebuf.MONO_VLSB
        )
 
        self.init_display()
 
    def command(self, cmd):
        if self.available:
            self.i2c.writeto(self.i2c_addr, bytes([0x00, cmd]))
 
    def init_display(self):
        commands = [
            0xAE,
            0xD5, 0x80,
            0xA8, 0x3F,
            0xD3, 0x00,
            0x40,
            0xAD, 0x8B,
            0xA1,
            0xC8,
            0xDA, 0x12,
            0x81, 0xCF,
            0xD9, 0xF1,
            0xDB, 0x40,
            0xA4,
            0xA6,
            0xAF
        ]
 
        for cmd in commands:
            self.command(cmd)
 
        time.sleep_ms(100)
        self.fill(0)
        self.show()
 
    def fill(self, color):
        if self.available:
            self.framebuf.fill(color)
 
    def text(self, string, x, y, color=1):
        if self.available:
            self.framebuf.text(string, x, y, color)
 
    def show(self):
        if not self.available:
            return
 
        # Send the framebuffer one 8-pixel-high page at a time.
        for page in range(self.height // 8):
            self.command(0xB0 + page)
            self.command(0x00)
            self.command(0x10)
 
            start = page * self.width
            data = self.buffer[start:start + self.width]
            self.i2c.writeto(self.i2c_addr, b'\x40' + data)
 
    def clear(self):
        if self.available:
            self.fill(0)
            self.show()
        self._last_lines = None
 
    def show_lines(self, line1, line2=""):
        """
        Display the two text lines supplied by the existing emote1.py
        state machine, centered on the 128x64 OLED.
        """
        line1 = str(line1)[:self.num_columns]
        line2 = str(line2)[:self.num_columns]
        current_lines = (line1, line2)
 
        if current_lines == self._last_lines:
            return
        self._last_lines = current_lines
 
        if not self.available:
            print("OLED | {} | {}".format(line1, line2))
            return
 
        self.fill(0)
 
        lines = [line1, line2]
        line_height = 10
        total_height = len(lines) * line_height
        start_y = max(0, (self.height - total_height) // 2)
 
        for index, line in enumerate(lines):
            x = max(0, (self.width - len(line) * 8) // 2)
            y = start_y + index * line_height
            self.text(line, x, y)
 
        self.show()
 
 
    @staticmethod
    def _wrap(text, width):
        """Word-wrap text into lines of at most width characters."""
        lines = []
        cur = ""
        for word in str(text).split():
            while len(word) > width:
                if cur:
                    lines.append(cur)
                    cur = ""
                lines.append(word[:width])
                word = word[width:]
            if not cur:
                cur = word
            elif len(cur) + 1 + len(word) <= width:
                cur = cur + " " + word
            else:
                lines.append(cur)
                cur = word
        if cur:
            lines.append(cur)
        return lines
 
    def show_prompt(self, icon_key, line1, line2=""):
        """
        Prompt layout: 64x64 icon on the left, question wrapped on the right
        (8 chars per line), [A]/[B] answers stacked at the bottom right.
        """
        question = self._wrap(str(line1).strip(), 8)[:4]
        answers = [p.strip()[:8] for p in str(line2).split("  ") if p.strip()][:2]
        current = ("PROMPT", icon_key, tuple(question), tuple(answers))
        if current == self._last_lines:
            return
        self._last_lines = current
 
        if not self.available:
            print("OLED | [{}] {} | {}".format(icon_key, " ".join(question), " ".join(answers)))
            return
 
        self.fill(0)
        icon = ICONS.get(icon_key) or ICONS["custom"]
        icon_fb = framebuf.FrameBuffer(icon, ICON_W, ICON_H, framebuf.MONO_VLSB)
        self.framebuf.blit(icon_fb, 0, 0)
 
        x = 68
        for i, text in enumerate(question):
            self.text(text, x, 4 + i * 10)
        for i, text in enumerate(answers):
            self.text(text, x, 44 + i * 10)
        self.show()
 
 
# =============================================================================
# 5. SENSOR HELPER (DIGITAL SHAKE PULSE DETECTOR)
# =============================================================================
 
class ShakeDetector:
    """Counts debounced falling-edge pulses from the digital shake sensor."""
    def __init__(self, pin_num):
        self.pulse_count = 0
        self._last_irq_ms = time.ticks_ms()
        self.pin = Pin(pin_num, Pin.IN, Pin.PULL_UP)
        # Count one edge per pulse. Counting both edges doubles the apparent
        # pulse rate and can make light shakes look like heavy shakes.
        self.pin.irq(trigger=Pin.IRQ_FALLING, handler=self._irq_handler)
        self._window_start = time.ticks_ms()
 
    def _irq_handler(self, _pin):
        # ticks_ms/ticks_diff and a small integer counter are IRQ-safe on Pico
        # MicroPython. Debounce the SW-420/ball-switch chatter.
        now = time.ticks_ms()
        if time.ticks_diff(now, self._last_irq_ms) >= SHAKE_IRQ_DEBOUNCE_MS:
            self.pulse_count += 1
            self._last_irq_ms = now
 
    def discard_window(self, now_ms):
        """Clear pulses while shake detection is intentionally disabled."""
        self.pulse_count = 0
        self._window_start = now_ms
 
    def evaluate_window(self, now_ms):
        """Returns 'heavy', 'light', or None once per SHAKE_WINDOW_MS."""
        if time.ticks_diff(now_ms, self._window_start) < SHAKE_WINDOW_MS:
            return None
 
        # Briefly disable interrupts so a pulse cannot be lost during reset.
        irq_state = machine.disable_irq()
        pulses = self.pulse_count
        self.pulse_count = 0
        machine.enable_irq(irq_state)
        self._window_start = now_ms
 
        if pulses >= SHAKE_HEAVY_PULSES:
            return "heavy"
        if pulses >= SHAKE_LIGHT_PULSES:
            return "light"
        return None
 
 
# =============================================================================
# 6. MAIN TAMAGOTCHI STATE MACHINE WITH SENSOR HIERARCHY
# =============================================================================
 
class TamagotchiMachine:
    STATE_NORMAL   = "NORMAL"
    STATE_PROMPT   = "PROMPT"
    STATE_REACTION = "REACTION"
 
    def __init__(self):
        # 1. Initialize LCD
        i2c = I2C(I2C_ID, sda=Pin(I2C_SDA_PIN), scl=Pin(I2C_SCL_PIN), freq=I2C_FREQ)
        self.lcd = I2cLcd(i2c, LCD_I2C_ADDR, LCD_ROWS, LCD_COLS)
 
        # 2. Initialize Content Provider
        self.content = ContentProvider(FACES, DEFAULT_PROMPTS)
 
        # 3. Initialize Buttons (Active-Low)
        self.btn_a = Pin(BTN_A_PIN, Pin.IN, Pin.PULL_UP)
        self.btn_b = Pin(BTN_B_PIN, Pin.IN, Pin.PULL_UP)
        # Non-blocking debounce state: never wait in a button handler while
        # another sensor event may be occurring.
        self._button_state = {
            "a": {"raw": self.btn_a.value(), "changed": time.ticks_ms(), "handled": False},
            "b": {"raw": self.btn_b.value(), "changed": time.ticks_ms(), "handled": False},
        }
 
        # 4. Initialize Touch & Vibration (Priority 1)
        self.touch_pin = Pin(TOUCH_PIN, Pin.IN, Pin.PULL_DOWN)
        self.vib_pin = Pin(VIB_PIN, Pin.OUT)
        self.vib_pin.value(0)
        self.vib_until_ms = 0
        self.touch_start_ms = None
        self.touch_long_triggered = False
 
        # 5. Initialize Shake Sensor (Priority 2)
        self.shake_sensor = ShakeDetector(SHAKE_PIN)
 
        # 6. Initialize BLE with inbound command callback
        ble = bluetooth.BLE()
        self.ble_uart = BLEUART(ble, rx_callback=self.handle_incoming_ble_command)
 
        # State Variables
        now = time.ticks_ms()
        self.state = self.STATE_NORMAL
        self.base_face_key = "normal"
        self.active_prompt = None
        self.reaction_until_ms = now
        self.last_prompt_ms = now
        self.next_blink_ms = time.ticks_add(now, IDLE_BLINK_INTERVAL_MS)
        self.blink_until_ms = None
 
    # -------------------------------------------------------------------------
    # INBOUND BLE COMMAND HANDLER (App -> Pico)
    # -------------------------------------------------------------------------
    def handle_incoming_ble_command(self, cmd: str):
        """
        Parses commands sent from the host/app:
          PROMPT:<line1>|<line2>  -> Injects an AI question onto the LCD
          FACE:<key_or_ascii>     -> Shows a specific emotion or reaction
          VIB:<ms>                -> Pulses vibration motor remotely
        """
        now = time.ticks_ms()
        print(f"[BLE RX] Command received: {cmd}")
 
        if cmd.startswith("PROMPT:"):
            # Format: PROMPT:Feeling tired?|[A]Yes    [B]No 
            payload = cmd[7:]
            parts = payload.split("|", 1)
            line1 = parts[0]
            line2 = parts[1] if len(parts) > 1 else "[A]Yes    [B]No "
            # Optional third field picks the icon: PROMPT:<l1>|<l2>|<icon>
            icon = "custom"
            if "|" in line2:
                line2, icon = line2.split("|", 1)
                icon = icon.strip()
            self.active_prompt = {
                "icon": icon,
                "line1": line1,
                "line2": line2,
                "face_a": "btn_a_happy",
                "face_b": "btn_b_thumbs_up",
            }
            self.state = self.STATE_PROMPT
            self._show_prompt(self.active_prompt)
            self.ble_uart.send("PROMPT:ACTIVE")
 
        elif cmd.startswith("FACE:"):
            face_val = cmd[5:]
            self._trigger_reaction(face_val, now, duration_ms=3000)
 
        elif cmd.startswith("VIB:"):
            try:
                ms = int(cmd[4:])
                self.vib_pin.value(1)
                self.vib_until_ms = time.ticks_add(now, ms)
            except ValueError:
                pass
 
    # -------------------------------------------------------------------------
    # DISPLAY & REACTION HELPERS
    # -------------------------------------------------------------------------
    def _show_face(self, face_key_or_literal):
        l1, l2 = self.content.get_face(face_key_or_literal)
        self.lcd.show_lines(l1, l2)
 
    def _show_prompt(self, prompt):
        self.lcd.show_prompt(prompt.get("icon", "custom"), prompt["line1"], prompt["line2"])
 
    def _trigger_reaction(self, face_key_or_literal, now_ms, duration_ms=REACTION_DISPLAY_MS):
        self.state = self.STATE_REACTION
        self.reaction_until_ms = time.ticks_add(now_ms, duration_ms)
        self._show_face(face_key_or_literal)
 
    # -------------------------------------------------------------------------
    # SENSOR HANDLERS (ENFORCING HIERARCHY)
    # -------------------------------------------------------------------------
    def _handle_touch(self, now_ms):
        """
        Hierarchy Level 1 (Top Priority):
        Directly drives the vibration motor and detects Short Tap vs. Long Hold.
        Returns True if Touch is actively engaged (used to lock out Shake).
        """
        is_touched = (self.touch_pin.value() == 1)
 
        if is_touched:
            # Active touch engages vibration immediately
            self.vib_pin.value(1)
 
            if self.touch_start_ms is None:
                self.touch_start_ms = now_ms
                self.touch_long_triggered = False
            else:
                held_ms = time.ticks_diff(now_ms, self.touch_start_ms)
                # Long hold threshold met
                if held_ms >= TOUCH_HOLD_MS and not self.touch_long_triggered:
                    self.touch_long_triggered = True
                    self._trigger_reaction("touch_long", now_ms)
                    self.ble_uart.send("TOUCH:HOLD")
                    print("[Event] Touch Long Hold -> Sent TOUCH:HOLD")
                elif self.touch_long_triggered:
                    # Keep reaction alive while held
                    self.reaction_until_ms = time.ticks_add(now_ms, 1000)
            return True
 
        else:
            # Touch released
            if self.touch_start_ms is not None:
                held_ms = time.ticks_diff(now_ms, self.touch_start_ms)
                # Short tap
                if TOUCH_MIN_MS <= held_ms < TOUCH_HOLD_MS and not self.touch_long_triggered:
                    self._trigger_reaction("touch_short", now_ms)
                    self.ble_uart.send("TOUCH:TAP")
                    print("[Event] Touch Tap -> Sent TOUCH:TAP")
 
                self.touch_start_ms = None
                self.touch_long_triggered = False
 
            # Turn off vibration unless an inbound remote VIB pulse is still running
            if time.ticks_diff(now_ms, self.vib_until_ms) >= 0:
                self.vib_pin.value(0)
 
            return False
 
    def _handle_shake(self, now_ms):
        """Hierarchy Level 2: Shake evaluated ONLY when Touch is idle."""
        shake_level = self.shake_sensor.evaluate_window(now_ms)
        if shake_level == "heavy":
            self._trigger_reaction("shaken_heavy", now_ms)
            self.ble_uart.send("SHAKE:HEAVY")
            print("[Event] Heavy Shake -> Sent SHAKE:HEAVY")
            return True
        elif shake_level == "light" and self.state == self.STATE_NORMAL:
            self._trigger_reaction("shaken_light", now_ms, duration_ms=1500)
            self.ble_uart.send("SHAKE:LIGHT")
            print("[Event] Light Shake -> Sent SHAKE:LIGHT")
            return True
        return False
 
    def _handle_buttons(self, now_ms):
        """Non-blocking active-low button debounce and prompt response."""
        events = []
        for key, pin in (("a", self.btn_a), ("b", self.btn_b)):
            state = self._button_state[key]
            raw = pin.value()
 
            if raw != state["raw"]:
                state["raw"] = raw
                state["changed"] = now_ms
 
            # A press is accepted only after the LOW level has been stable
            # for DEBOUNCE_MS. It is handled once until the button is released.
            if raw == 0 and not state["handled"]:
                if time.ticks_diff(now_ms, state["changed"]) >= DEBOUNCE_MS:
                    state["handled"] = True
                    events.append(key)
            elif raw == 1:
                state["handled"] = False
 
        for key in events:
            if key == "a":
                self.ble_uart.send("BTN:YES")
                print("[Event] Button [A] pressed -> Sent BTN:YES")
                if self.state == self.STATE_PROMPT and self.active_prompt:
                    face = self.active_prompt.get("face_a", "btn_a_happy")
                    self._trigger_reaction(face, now_ms)
            else:
                self.ble_uart.send("BTN:NO")
                print("[Event] Button [B] pressed -> Sent BTN:NO")
                if self.state == self.STATE_PROMPT and self.active_prompt:
                    face = self.active_prompt.get("face_b", "btn_b_thumbs_up")
                    self._trigger_reaction(face, now_ms)
 
        return bool(events)
 
    def _render_idle_face(self, now_ms):
        """Show the normal face with a brief automatic blink at intervals."""
        if self.blink_until_ms is not None:
            if time.ticks_diff(now_ms, self.blink_until_ms) >= 0:
                self.blink_until_ms = None
                self._show_face(self.base_face_key)
            return
 
        if time.ticks_diff(now_ms, self.next_blink_ms) >= 0:
            self._show_face("blink")
            self.blink_until_ms = time.ticks_add(now_ms, IDLE_BLINK_DURATION_MS)
            self.next_blink_ms = time.ticks_add(now_ms, IDLE_BLINK_INTERVAL_MS)
        else:
            self._show_face(self.base_face_key)
 
    # -------------------------------------------------------------------------
    # MAIN STEP EXECUTION
    # -------------------------------------------------------------------------
    def step(self):
        now = time.ticks_ms()
 
        # 1. Non-blocking button polling; sensor handlers continue every loop.
        self._handle_buttons(now)
 
        # 2. Priority Level 1: Capacitive Touch (TTP223 is active-high).
        touch_active = self._handle_touch(now)
 
        # 3. Priority Level 2: shake only when touch is idle and no prompt is
        # active. Discard disabled-period pulses so they cannot trigger later.
        if not touch_active and self.state != self.STATE_PROMPT:
            self._handle_shake(now)
        else:
            self.shake_sensor.discard_window(now)
 
        # 4. Local timer prompts.
        if self.state == self.STATE_NORMAL:
            if time.ticks_diff(now, self.last_prompt_ms) >= LOCAL_PROMPT_INTERVAL_MS:
                self.active_prompt = self.content.get_random_prompt()
                self.state = self.STATE_PROMPT
                self._show_prompt(self.active_prompt)
                self.ble_uart.send("PROMPT:LOCAL_ACTIVE")
 
        # 5. Expire reactions, then render idle face only when truly idle.
        if self.state == self.STATE_REACTION:
            if time.ticks_diff(now, self.reaction_until_ms) >= 0:
                self.state = self.STATE_NORMAL
                self.last_prompt_ms = now
                self.next_blink_ms = time.ticks_add(now, IDLE_BLINK_INTERVAL_MS)
                self.blink_until_ms = None
                self._show_face(self.base_face_key)
 
        if self.state == self.STATE_NORMAL:
            self._render_idle_face(now)
 
    def run(self):
        print("[System] Pebble Pico W running. Awaiting BLE connections...")
        self._show_face(self.base_face_key)
        while True:
            self.step()
            time.sleep_ms(20)
 
 
# =============================================================================
# ENTRY POINT
# =============================================================================
if __name__ == "__main__":
    tamagotchi = TamagotchiMachine()
    tamagotchi.run()
