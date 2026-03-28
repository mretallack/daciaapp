#include <jni.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <android/log.h>

#define TAG "NngSdkProbe"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)

static void* sdk_handle = NULL;
static void* sdk_base = NULL;

// Call JNI_OnLoad manually to let the SDK init its globals
static int init_sdk(JNIEnv *env) {
    if (sdk_handle) return 1;

    sdk_handle = dlopen("liblib_nng_sdk.so", RTLD_NOW);
    if (!sdk_handle) {
        LOGI("dlopen failed: %s", dlerror());
        return 0;
    }

    // Get base address
    Dl_info info;
    void* sym = dlsym(sdk_handle, "ifapi_token_alloc_symbol_range");
    if (sym && dladdr(sym, &info)) {
        sdk_base = info.dli_fbase;
    }

    // Call JNI_OnLoad to let the SDK set up its globals
    typedef jint (*fn_jni_onload)(JavaVM*, void*);
    fn_jni_onload onload = (fn_jni_onload)dlsym(sdk_handle, "JNI_OnLoad");
    if (onload) {
        JavaVM* vm;
        (*env)->GetJavaVM(env, &vm);
        LOGI("Calling JNI_OnLoad...");
        jint ver = onload(vm, NULL);
        LOGI("JNI_OnLoad returned: %d", ver);
    }

    return sdk_handle != NULL;
}

JNIEXPORT jstring JNICALL
Java_com_dacia_nftpprobe_NngProbe_probeSymbols(JNIEnv *env, jclass clazz) {
    char result[16384];
    int pos = 0;

    if (!init_sdk(env)) {
        pos += snprintf(result + pos, sizeof(result) - pos, "SDK init failed: %s\n", dlerror());
        return (*env)->NewStringUTF(env, result);
    }
    pos += snprintf(result + pos, sizeof(result) - pos, "SDK loaded, base=%p\n", sdk_base);

    // Now try ifapi_token_alloc_symbol_range — should work after JNI_OnLoad
    typedef unsigned long long (*fn_alloc)(unsigned int, const char**);
    fn_alloc alloc = (fn_alloc)dlsym(sdk_handle, "ifapi_token_alloc_symbol_range");
    if (!alloc) {
        pos += snprintf(result + pos, sizeof(result) - pos, "alloc not found\n");
        return (*env)->NewStringUTF(env, result);
    }

    const char* syms[] = {
        "call", "length", "WHICH", "serialize", "getItem",
        "splice", "list", "remoteConfig", "iterator", "constructor",
        "proto", "asyncIterator", "dispose", "asyncDispose",
        "md5", "sha1", "stopStream", "pauseStream", "resumeStream",
        "control", "response", "request", "returns",
        "getAndRemove", "get", "compact", "error",
        "children", "name", "size", "ls", "path",
        "device", "brand", "fileMapping", "freeSpace", "diskInfo",
        "swid", "appcid", "igoVersion", "imei", "vin",
        "agentBrand", "modelName", "brandName", "brandFiles",
    };
    int count = sizeof(syms) / sizeof(syms[0]);

    // Allocate one at a time
    pos += snprintf(result + pos, sizeof(result) - pos, "\n=== Symbols ===\n");
    for (int i = 0; i < count; i++) {
        const char* name = syms[i];
        unsigned long long ret = alloc(1, &name);
        unsigned int id = (unsigned int)(ret & 0xFFFFFFFF);
        unsigned int cnt = (unsigned int)(ret >> 32);
        pos += snprintf(result + pos, sizeof(result) - pos,
            "@%-20s = %u (ok=%u)\n", name, id, cnt);
        LOGI("@%s = %u (ok=%u)", name, id, cnt);
    }

    return (*env)->NewStringUTF(env, result);
}
