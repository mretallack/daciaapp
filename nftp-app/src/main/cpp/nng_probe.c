#include <jni.h>
#include <string.h>
#include <stdio.h>
#include <dlfcn.h>
#include <android/log.h>

#define TAG "NngSdkProbe"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)

// Ghidra uses image base 0x100000, real offsets are ghidra_addr - 0x100000
#define GHIDRA_BASE 0x100000
#define REAL_OFFSET(ghidra_addr) ((ghidra_addr) - GHIDRA_BASE)

JNIEXPORT jstring JNICALL
Java_com_dacia_nftpprobe_NngProbe_probeSymbols(JNIEnv *env, jclass clazz, jstring xsRoot) {
    char result[16384];
    int pos = 0;

    pos += snprintf(result + pos, sizeof(result) - pos, "SDK loaded\n");

    // InitializeNative to create symbol table
    jclass sdkClass = (*env)->FindClass(env, "com/nng/core/SDK");
    jmethodID setRoot = (*env)->GetStaticMethodID(env, sdkClass, "SetRootPathNative", "(Ljava/lang/String;)V");
    (*env)->CallStaticVoidMethod(env, sdkClass, setRoot, xsRoot);
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);

    jclass configClass = (*env)->FindClass(env, "com/nng/core/SDK$Configuration");
    jmethodID configInit = (*env)->GetMethodID(env, configClass, "<init>", "()V");
    jobject config = (*env)->NewObject(env, configClass, configInit);
    (*env)->SetObjectField(env, config,
        (*env)->GetFieldID(env, configClass, "rootPath", "Ljava/lang/String;"), xsRoot);

    jclass helperClass = (*env)->FindClass(env, "com/dacia/nftpprobe/NoOpConsumer");
    jobject consumer = (*env)->NewObject(env, helperClass,
        (*env)->GetMethodID(env, helperClass, "<init>", "()V"));
    (*env)->SetObjectField(env, config,
        (*env)->GetFieldID(env, configClass, "onEngineStatusChange", "Ljava/util/function/Consumer;"), consumer);

    jmethodID initNative = (*env)->GetStaticMethodID(env, sdkClass, "InitializeNative",
        "(Lcom/nng/core/SDK$Configuration;)V");
    (*env)->CallStaticVoidMethod(env, sdkClass, initNative, config);
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
        pos += snprintf(result + pos, sizeof(result) - pos, "InitializeNative exception\n");
    } else {
        pos += snprintf(result + pos, sizeof(result) - pos, "InitializeNative OK\n");
    }

    // Get base address
    void* sdk_h = dlopen("liblib_nng_sdk.so", RTLD_NOLOAD);
    Dl_info info;
    void* any_sym = dlsym(sdk_h, "ifapi_token_from_identifier");
    void* base = NULL;
    if (any_sym && dladdr(any_sym, &info)) base = info.dli_fbase;

    // Verify: ifapi_token_from_identifier should be at base + 0xfec4f8
    void* expected = (char*)base + 0xfec4f8;
    pos += snprintf(result + pos, sizeof(result) - pos,
        "Base: %p\nVerify: dlsym=%p calc=%p match=%s\n",
        base, any_sym, expected, (any_sym == expected) ? "YES" : "NO");

    // FUN_00af8b08 in Ghidra = offset 0x9f8b08 in real binary
    typedef unsigned int (*fn_intern)(const char*);
    fn_intern intern = (fn_intern)((char*)base + REAL_OFFSET(0x00af8b08));
    pos += snprintf(result + pos, sizeof(result) - pos, "intern at: %p\n", intern);

    const char* syms[] = {
        "call", "length", "WHICH", "serialize", "getItem",
        "splice", "list", "remoteConfig", "iterator", "constructor",
        "proto", "asyncIterator", "dispose", "asyncDispose",
        "md5", "sha1", "compact", "error", "children",
        "name", "size", "ls", "path",
        "device", "brand", "fileMapping", "freeSpace", "diskInfo",
        "get", "response", "request", "control",
    };
    int count = sizeof(syms) / sizeof(syms[0]);

    pos += snprintf(result + pos, sizeof(result) - pos, "\n=== intern() ===\n");
    for (int i = 0; i < count; i++) {
        unsigned int id = intern(syms[i]);
        pos += snprintf(result + pos, sizeof(result) - pos,
            "@%-20s = %u\n", syms[i], id);
        LOGI("@%s = %u", syms[i], id);
    }

    // Verify idempotent
    pos += snprintf(result + pos, sizeof(result) - pos, "\n=== verify ===\n");
    for (int i = 0; i < 5; i++) {
        unsigned int id = intern(syms[i]);
        pos += snprintf(result + pos, sizeof(result) - pos,
            "@%-20s = %u\n", syms[i], id);
    }

    return (*env)->NewStringUTF(env, result);
}
