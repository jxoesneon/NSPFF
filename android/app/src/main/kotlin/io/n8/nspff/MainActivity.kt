package io.n8.nspff

import android.content.Context
import android.hardware.input.InputManager
import android.view.InputDevice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "io.n8.nspff/gamepad"
    private var channel: MethodChannel? = null
    private var inputManager: InputManager? = null
    private var inputListener: InputManager.InputDeviceListener? = null

    private var isGamepadConnectedState: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        inputManager = getSystemService(Context.INPUT_SERVICE) as? InputManager

        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isGamepadConnected" -> {
                    result.success(checkGamepadConnected())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        inputListener = object : InputManager.InputDeviceListener {
            override fun onInputDeviceAdded(deviceId: Int) {
                notifyConnectionChanged()
            }

            override fun onInputDeviceRemoved(deviceId: Int) {
                notifyConnectionChanged()
            }

            override fun onInputDeviceChanged(deviceId: Int) {
                notifyConnectionChanged()
            }
        }

        inputManager?.registerInputDeviceListener(inputListener, null)
    }

    override fun dispatchKeyEvent(event: android.view.KeyEvent?): Boolean {
        if (event != null && isGamepadKeyEvent(event)) {
            if (!isGamepadConnectedState) {
                isGamepadConnectedState = true
                runOnUiThread {
                    channel?.invokeMethod("onGamepadConnectionChanged", true)
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun isGamepadKeyEvent(event: android.view.KeyEvent): Boolean {
        val source = event.source
        if ((source and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD ||
            (source and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK) {
            return true
        }
        return when (event.keyCode) {
            android.view.KeyEvent.KEYCODE_BUTTON_A,
            android.view.KeyEvent.KEYCODE_BUTTON_B,
            android.view.KeyEvent.KEYCODE_BUTTON_C,
            android.view.KeyEvent.KEYCODE_BUTTON_X,
            android.view.KeyEvent.KEYCODE_BUTTON_Y,
            android.view.KeyEvent.KEYCODE_BUTTON_Z,
            android.view.KeyEvent.KEYCODE_BUTTON_L1,
            android.view.KeyEvent.KEYCODE_BUTTON_R1,
            android.view.KeyEvent.KEYCODE_BUTTON_L2,
            android.view.KeyEvent.KEYCODE_BUTTON_R2,
            android.view.KeyEvent.KEYCODE_BUTTON_THUMBL,
            android.view.KeyEvent.KEYCODE_BUTTON_THUMBR,
            android.view.KeyEvent.KEYCODE_BUTTON_START,
            android.view.KeyEvent.KEYCODE_BUTTON_SELECT,
            android.view.KeyEvent.KEYCODE_BUTTON_MODE -> true
            else -> false
        }
    }

    private fun checkGamepadConnected(): Boolean {
        val manager = inputManager ?: (getSystemService(Context.INPUT_SERVICE) as? InputManager) ?: return false
        val deviceIds = manager.inputDeviceIds ?: return false
        for (id in deviceIds) {
            val device = manager.getInputDevice(id) ?: continue
            val sources = device.sources
            val isGamepad = (sources and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
            val isJoystick = (sources and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
            if (!device.isVirtual && (isGamepad || isJoystick)) {
                return true
            }
        }
        return isGamepadConnectedState
    }

    private fun notifyConnectionChanged() {
        val isConnected = checkGamepadConnected()
        isGamepadConnectedState = isConnected
        runOnUiThread {
            channel?.invokeMethod("onGamepadConnectionChanged", isConnected)
        }
    }

    override fun onDestroy() {
        inputListener?.let { inputManager?.unregisterInputDeviceListener(it) }
        super.onDestroy()
    }
}
