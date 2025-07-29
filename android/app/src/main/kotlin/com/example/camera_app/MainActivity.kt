package com.example.camera_app

import android.content.ContentValues
import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.camera_app/gallery"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveVideoToGallery" -> {
                    val videoPath = call.argument<String>("videoPath")
                    val dateTime = call.argument<String>("dateTime")
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    
                    if (videoPath != null && dateTime != null && latitude != null && longitude != null) {
                        try {
                            val savedUri = saveVideoToGallery(videoPath, dateTime, latitude, longitude)
                            result.success("Video saved successfully: $savedUri")
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", "Failed to save video: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun saveVideoToGallery(
        videoPath: String,
        dateTime: String,
        latitude: Double,
        longitude: Double
    ): Uri? {
        val videoFile = File(videoPath)
        if (!videoFile.exists()) {
            throw Exception("Video file does not exist")
        }

        val contentResolver = contentResolver
        val timestamp = System.currentTimeMillis()
        val displayName = "video_${timestamp}.mp4"
        
        val contentValues = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.DATE_ADDED, timestamp / 1000)
            put(MediaStore.Video.Media.DATE_MODIFIED, timestamp / 1000)
            
            // Add location data if available
            if (latitude != 0.0 && longitude != 0.0) {
                put(MediaStore.Video.Media.LATITUDE, latitude)
                put(MediaStore.Video.Media.LONGITUDE, longitude)
            }
            
            // For Android 10 and above
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES)
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
        }

        val uri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, contentValues)
        
        uri?.let { videoUri ->
            contentResolver.openOutputStream(videoUri)?.use { outputStream ->
                FileInputStream(videoFile).use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            }
            
            // Mark as not pending for Android 10+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.Video.Media.IS_PENDING, 0)
                contentResolver.update(videoUri, contentValues, null, null)
            }
            
            // Clean up the temporary file
            videoFile.delete()
            
            return videoUri
        }
        
        throw Exception("Failed to create media store entry")
    }
}