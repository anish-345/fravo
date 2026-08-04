package avionti.fravo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register on the main engine explicitly (belt-and-suspenders).
        flutterEngine.plugins.add(GoHomePlugin())
    }
}
