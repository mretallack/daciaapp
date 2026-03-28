#include <jni.h>
#include <string.h>
#include <stdio.h>
#include <android/log.h>

#define TAG "NngSdkProbe"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)

JNIEXPORT jstring JNICALL
Java_com_dacia_nftpprobe_NngProbe_probeSymbols(JNIEnv *env, jclass clazz, jstring xsRoot) {
    // This is now a no-op - use NngEngine instead
    return (*env)->NewStringUTF(env, "Use 'Start NNG Engine' button instead.\n\nThe NNG SDK requires the full engine to be running to resolve symbols.");
}
