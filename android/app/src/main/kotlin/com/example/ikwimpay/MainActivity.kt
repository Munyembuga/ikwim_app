package com.example.ikwimpay
// In your MainActivity.kt or a separate PrinterPlugin.kt file
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.os.RemoteException
import com.sunmi.peripheral.printer.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.sunmi_printer"
    private var sunmiPrinterService: SunmiPrinterService? = null
    private val printCallback = object : InnerPrinterCallback() {
        override fun onConnected(service: SunmiPrinterService) {
            sunmiPrinterService = service
            checkPrinterStatus()
        }

        override fun onDisconnected() {
            sunmiPrinterService = null
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initPrinter" -> {
                    initPrinter()
                    result.success(true)
                }
                "printReceipt" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes != null) {
                        printReceipt(bytes)
                        result.success(true)
                    } else {
                        result.error("PRINT_ERROR", "No valid data to print", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initPrinter() {
        try {
            InnerPrinterManager.getInstance().bindService(this, printCallback)
        } catch (e: InnerPrinterException) {
            e.printStackTrace()
        }
    }

    private fun checkPrinterStatus() {
        if (sunmiPrinterService == null) {
            return
        }
        
        try {
            val printerStatus = sunmiPrinterService!!.updatePrinterState()
            
            // Status could be:
            // 1 = OK
            // 2 = Out of paper
            // 3 = Cover open
            // 4 = Printer error
            
            if (printerStatus != 1) {
                // Handle printer not ready
            }
        } catch (e: RemoteException) {
            e.printStackTrace()
        }
    }

    private fun printReceipt(bytes: ByteArray) {
        if (sunmiPrinterService == null) {
            // Try to reconnect
            initPrinter()
            return
        }
        
        try {
            sunmiPrinterService!!.sendRAWData(bytes, null)
        } catch (e: RemoteException) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (sunmiPrinterService != null) {
            try {
                InnerPrinterManager.getInstance().unBindService(this, printCallback)
                sunmiPrinterService = null
            } catch (e: InnerPrinterException) {
                e.printStackTrace()
            }
        }
    }
}