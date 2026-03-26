package com.dacia.nftpprobe;

import android.app.Activity;
import android.content.Intent;
import android.hardware.usb.UsbAccessory;
import android.hardware.usb.UsbManager;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ScrollView;
import android.widget.TextView;

import com.dacia.nftp.NftpProbe;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.net.Socket;

public class MainActivity extends Activity {

    private TextView txtLog;
    private ScrollView scrollView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        txtLog = findViewById(R.id.txtLog);
        scrollView = findViewById(R.id.scrollView);
        EditText editHost = findViewById(R.id.editHost);
        Button btnConnect = findViewById(R.id.btnConnect);

        btnConnect.setOnClickListener(v -> {
            String host = editHost.getText().toString().trim();
            if (!host.isEmpty()) {
                runProbeOverTcp(host, 9876);
            }
        });

        handleIntent(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleIntent(intent);
    }

    private void handleIntent(Intent intent) {
        if (intent == null) return;

        String emuHost = intent.getStringExtra("emulator_host");
        if (emuHost != null) {
            runProbeOverTcp(emuHost, 9876);
            return;
        }

        UsbAccessory accessory = intent.getParcelableExtra(UsbManager.EXTRA_ACCESSORY);
        if (accessory != null) {
            runProbeOverUsb(accessory);
        }
    }

    private void runProbeOverTcp(String host, int port) {
        log("Connecting to " + host + ":" + port + "...");
        new Thread(() -> {
            try (Socket sock = new Socket(host, port)) {
                NftpProbe.run(sock.getInputStream(), sock.getOutputStream(), this::log);
            } catch (Exception e) {
                log("TCP error: " + e.getMessage());
            }
        }).start();
    }

    private void runProbeOverUsb(UsbAccessory accessory) {
        log("Opening USB accessory: " + accessory.getManufacturer() + "/" + accessory.getModel());
        UsbManager usb = (UsbManager) getSystemService(USB_SERVICE);
        new Thread(() -> {
            try {
                ParcelFileDescriptor pfd = usb.openAccessory(accessory);
                if (pfd == null) {
                    log("Failed to open accessory");
                    return;
                }
                try (FileInputStream in = new FileInputStream(pfd.getFileDescriptor());
                     FileOutputStream out = new FileOutputStream(pfd.getFileDescriptor())) {
                    NftpProbe.run(in, out, this::log);
                } finally {
                    pfd.close();
                }
            } catch (Exception e) {
                log("USB error: " + e.getMessage());
            }
        }).start();
    }

    private void log(String msg) {
        android.util.Log.i("NftpProbe", msg);
        runOnUiThread(() -> {
            txtLog.append(msg + "\n");
            scrollView.post(() -> scrollView.fullScroll(ScrollView.FOCUS_DOWN));
        });
    }
}
