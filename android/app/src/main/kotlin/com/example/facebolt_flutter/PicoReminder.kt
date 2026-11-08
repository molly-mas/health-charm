package com.example.facebolt_flutter

import android.Manifest
import android.app.Activity
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

internal class PicoReminder(private val activity: Activity) {
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var scanner: BluetoothLeScanner? = null
    private var gatt: BluetoothGatt? = null
    private var payload = byteArrayOf()
    private val timeout = Runnable { finish("Pico W did not respond. Check that it is powered on and nearby.") }

    private val scan = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            handler.post {
                if (pending == null || scanner == null) return@post
                try {
                    scanner?.stopScan(this)
                    scanner = null
                    gatt = result.device.connectGatt(activity, false, connection, BluetoothDevice.TRANSPORT_LE)
                    if (gatt == null) finish("Could not connect to Pico W")
                } catch (_: SecurityException) {
                    finish("Allow Nearby devices access to send reminders")
                }
            }
        }

        override fun onScanFailed(errorCode: Int) {
            handler.post { if (scanner != null) finish("Bluetooth scan failed ($errorCode)") }
        }
    }

    private val connection = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(client: BluetoothGatt, status: Int, state: Int) {
            handler.post {
                if (client != gatt) return@post
                if (status != BluetoothGatt.GATT_SUCCESS || state == BluetoothProfile.STATE_DISCONNECTED) {
                    finish("Pico W disconnected before receiving the reminder")
                } else if (state == BluetoothProfile.STATE_CONNECTED) {
                    if (!client.discoverServices()) finish("Could not read Pico W services")
                }
            }
        }

        @Suppress("DEPRECATION")
        override fun onServicesDiscovered(client: BluetoothGatt, status: Int) {
            handler.post {
                if (client != gatt) return@post
                val characteristic = client.getService(service)?.getCharacteristic(display)
                if (status != BluetoothGatt.GATT_SUCCESS || characteristic == null) {
                    finish("Pico W display service is unavailable")
                    return@post
                }
                val accepted = if (Build.VERSION.SDK_INT >= 33) {
                    client.writeCharacteristic(characteristic, payload, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) ==
                        BluetoothStatusCodes.SUCCESS
                } else {
                    characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                    characteristic.value = payload
                    client.writeCharacteristic(characteristic)
                }
                if (!accepted) finish("Could not send reminder to Pico W")
            }
        }

        override fun onCharacteristicWrite(client: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            handler.post {
                if (client == gatt) finish(
                    if (status == BluetoothGatt.GATT_SUCCESS) null else "Pico W rejected the reminder"
                )
            }
        }
    }

    fun send(icon: String?, result: MethodChannel.Result) {
        if (icon !in setOf("eat", "water", "chat", "walk", "custom")) {
            result.error("ICON", "Unknown reminder icon", null)
            return
        }
        if (pending != null) {
            result.error("BUSY", "A reminder is already being sent", null)
            return
        }
        pending = result
        payload = byteArrayOf(0xff.toByte()) + icon!!.toByteArray(Charsets.US_ASCII)
        val permissions = if (Build.VERSION.SDK_INT >= 31) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        val missing = permissions.filter { activity.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isEmpty()) startScan()
        else activity.requestPermissions(missing.toTypedArray(), permissionRequest)
    }

    fun permissionsResult(grants: IntArray) {
        if (pending == null) return
        if (grants.isNotEmpty() && grants.all { it == PackageManager.PERMISSION_GRANTED }) startScan()
        else finish("Bluetooth permission is required to send reminders to Pico W")
    }

    private fun startScan() {
        try {
            val adapter = activity.getSystemService(BluetoothManager::class.java)?.adapter
            scanner = adapter?.bluetoothLeScanner
            val activeScanner = scanner ?: run {
                finish("Turn on Bluetooth to send reminders to Pico W")
                return
            }
            handler.postDelayed(timeout, 12000)
            activeScanner.startScan(
                listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(service)).build()),
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),
                scan
            )
        } catch (error: RuntimeException) {
            finish(error.message ?: "Could not start Bluetooth scan")
        }
    }

    fun finish(error: String?) {
        handler.removeCallbacks(timeout)
        val result = pending
        pending = null
        try { scanner?.stopScan(scan) } catch (_: SecurityException) {}
        scanner = null
        try { gatt?.close() } catch (_: SecurityException) {}
        gatt = null
        if (error == null) result?.success(null)
        else result?.error("PICO", error, null)
    }

    companion object {
        const val permissionRequest = 7042
        private val service = UUID.fromString("0000ffe0-0000-1000-8000-00805f9b34fb")
        private val display = UUID.fromString("0000ffe2-0000-1000-8000-00805f9b34fb")
    }
}
