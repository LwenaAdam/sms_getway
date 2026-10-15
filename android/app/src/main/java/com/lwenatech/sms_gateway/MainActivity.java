package com.lwenatech.sms_gateway;

import android.Manifest;
import android.app.PendingIntent;
import android.content.ContentResolver;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.os.Build;
import android.provider.ContactsContract;
import android.telephony.SmsManager;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import com.lwenatech.sms_gateway.services.MarketingMethodChannelHandler;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.lwenatech.sms_gateway/sms";
    private static final String MARKETING_CHANNEL = "com.lwenatech.sms_gateway/marketing";
    private static final String PHONEBOOK_CHANNEL = "com.lwenatech.sms_gateway/phonebook";
    private static final String SMS_SENT = "SMS_SENT";
    private static final String SMS_DELIVERED = "SMS_DELIVERED";
    private int sentCount = 0;
    private List<String> failedNumbers = new ArrayList<>();

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "sendSms": {
                        String phoneNumber = call.argument("phoneNumber");
                        String message = call.argument("message");
                        if (phoneNumber != null && message != null) {
                            sendSms(phoneNumber, message, result);
                        } else {
                            result.error("INVALID_ARGS", "Phone number or message is null", null);
                        }
                        break;
                    }
                    case "sendBulkSms": {
                        List<String> phoneNumbers = call.argument("phoneNumbers");
                        String message = call.argument("message");
                        if (phoneNumbers != null && message != null) {
                            sendBulkSms(phoneNumbers, message, result);
                        } else {
                            result.error("INVALID_ARGS", "Phone numbers or message is null", null);
                        }
                        break;
                    }
                    case "checkSmsPermission": {
                        boolean hasPermission = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.SEND_SMS
                        ) == PackageManager.PERMISSION_GRANTED;
                        result.success(hasPermission);
                        break;
                    }
                    case "requestSmsPermission": {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            ActivityCompat.requestPermissions(
                                this,
                                new String[]{Manifest.permission.SEND_SMS},
                                1001
                            );
                            result.success(true);
                        } else {
                            result.success(true);
                        }
                        break;
                    }
                    default:
                        result.notImplemented();
                        break;
                }
            });

        MethodChannel marketingChannel = new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(), 
            MARKETING_CHANNEL
        );
        MarketingMethodChannelHandler.register(marketingChannel, getApplicationContext());

        // Phonebook channel for contacts sync
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), PHONEBOOK_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "checkContactsPermission": {
                        boolean hasPermission = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_CONTACTS
                        ) == PackageManager.PERMISSION_GRANTED;
                        result.success(hasPermission);
                        break;
                    }
                    case "requestContactsPermission": {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            ActivityCompat.requestPermissions(
                                this,
                                new String[]{Manifest.permission.READ_CONTACTS},
                                1002
                            );
                            result.success(true);
                        } else {
                            result.success(true);
                        }
                        break;
                    }
                    case "getPhonebookContacts": {
                        getPhonebookContacts(result);
                        break;
                    }
                    default:
                        result.notImplemented();
                        break;
                }
            });
    }

    private void sendSms(String phoneNumber, String message, MethodChannel.Result result) {
        try {
            // Check permission
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS)
                != PackageManager.PERMISSION_GRANTED) {
                result.error("PERMISSION_DENIED", "SMS permission not granted", null);
                return;
            }

            SmsManager smsManager;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                smsManager = getSystemService(SmsManager.class);
            } else {
                smsManager = SmsManager.getDefault();
            }

            // Create PendingIntent for SMS_SENT
            Intent sentIntent = new Intent(SMS_SENT);
            PendingIntent sentPendingIntent;
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                sentPendingIntent = PendingIntent.getBroadcast(
                    this, 0, sentIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );
            } else {
                sentPendingIntent = PendingIntent.getBroadcast(
                    this, 0, sentIntent, 
                    PendingIntent.FLAG_UPDATE_CURRENT
                );
            }

            // Clean/sanitize phone number
            String cleanPhone = phoneNumber.replaceAll("[\\s\\-\\(\\)]", "");

            // Handle multi-part/long SMS automatically if > 160 chars
            ArrayList<String> parts = smsManager.divideMessage(message);
            if (parts.size() > 1) {
                ArrayList<PendingIntent> sentIntents = new ArrayList<>();
                for (int i = 0; i < parts.size(); i++) {
                    sentIntents.add(sentPendingIntent);
                }
                smsManager.sendMultipartTextMessage(cleanPhone, null, parts, sentIntents, null);
            } else {
                smsManager.sendTextMessage(cleanPhone, null, message, sentPendingIntent, null);
            }
            result.success(true);
        } catch (Exception e) {
            result.error("SEND_ERROR", e.getMessage(), null);
        }
    }

    private void sendBulkSms(List<String> phoneNumbers, String message, MethodChannel.Result result) {
        try {
            // Check permission
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS)
                != PackageManager.PERMISSION_GRANTED) {
                result.error("PERMISSION_DENIED", "SMS permission not granted", null);
                return;
            }

            sentCount = 0;
            failedNumbers.clear();

            SmsManager smsManager;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                smsManager = getSystemService(SmsManager.class);
            } else {
                smsManager = SmsManager.getDefault();
            }

            // Send SMS to each number
            for (String phoneNumber : phoneNumbers) {
                try {
                    Intent sentIntent = new Intent(SMS_SENT);
                    sentIntent.putExtra("phoneNumber", phoneNumber);

                    PendingIntent sentPendingIntent;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        sentPendingIntent = PendingIntent.getBroadcast(
                            this, phoneNumber.hashCode(), sentIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                        );
                    } else {
                        sentPendingIntent = PendingIntent.getBroadcast(
                            this, phoneNumber.hashCode(), sentIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT
                        );
                    }

                    String cleanPhone = phoneNumber.replaceAll("[\\s\\-\\(\\)]", "");

                    ArrayList<String> parts = smsManager.divideMessage(message);
                    if (parts.size() > 1) {
                        ArrayList<PendingIntent> sentIntents = new ArrayList<>();
                        for (int i = 0; i < parts.size(); i++) {
                            sentIntents.add(sentPendingIntent);
                        }
                        smsManager.sendMultipartTextMessage(cleanPhone, null, parts, sentIntents, null);
                    } else {
                        smsManager.sendTextMessage(cleanPhone, null, message, sentPendingIntent, null);
                    }
                    sentCount++;
                } catch (Exception e) {
                    failedNumbers.add(phoneNumber);
                }
            }

            Map<String, Object> resultMap = new HashMap<>();
            resultMap.put("successCount", sentCount);
            resultMap.put("failedNumbers", failedNumbers);
            result.success(resultMap);
        } catch (Exception e) {
            result.error("SEND_ERROR", e.getMessage(), null);
        }
    }

    private void getPhonebookContacts(MethodChannel.Result result) {
        try {
            // Check permission
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS)
                != PackageManager.PERMISSION_GRANTED) {
                result.error("PERMISSION_DENIED", "Contacts permission not granted", null);
                return;
            }

            List<Map<String, String>> contacts = new ArrayList<>();
            ContentResolver contentResolver = getContentResolver();

            // Query contacts
            Cursor cursor = contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                new String[]{
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                },
                null,
                null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
            );

            if (cursor != null) {
                int nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME);
                int numberIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER);

                while (cursor.moveToNext()) {
                    String name = cursor.getString(nameIndex);
                    String phoneNumber = cursor.getString(numberIndex);

                    if (phoneNumber != null && !phoneNumber.trim().isEmpty()) {
                        Map<String, String> contact = new HashMap<>();
                        contact.put("name", name != null ? name : "");
                        contact.put("phoneNumber", phoneNumber.trim());
                        contacts.add(contact);
                    }
                }
                cursor.close();
            }

            result.success(contacts);
        } catch (Exception e) {
            result.error("READ_ERROR", e.getMessage(), null);
        }
    }
}
