#include <IOKit/IOKitLib.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define IFANS_SMC_KERNEL_INDEX 2
#define IFANS_SMC_CMD_READ_BYTES 5
#define IFANS_SMC_CMD_WRITE_BYTES 6
#define IFANS_SMC_CMD_READ_KEYINFO 9

typedef char IFansSMCBytes[32];

typedef struct {
    char major;
    char minor;
    char build;
    char reserved[1];
    uint16_t release;
} IFansSMCVersion;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} IFansSMCPLimitData;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    char dataAttributes;
} IFansSMCKeyInfo;

typedef struct {
    uint32_t key;
    IFansSMCVersion version;
    IFansSMCPLimitData pLimitData;
    IFansSMCKeyInfo keyInfo;
    char result;
    char status;
    char data8;
    uint32_t data32;
    IFansSMCBytes bytes;
} IFansSMCKeyData;

typedef struct {
    io_connect_t connection;
} IFansSMCHandle;

static uint32_t ifans_smc_strtoul4(const char *string) {
    if (string == NULL) {
        return 0;
    }

    return ((uint32_t)(uint8_t)string[0] << 24) |
        ((uint32_t)(uint8_t)string[1] << 16) |
        ((uint32_t)(uint8_t)string[2] << 8) |
        (uint32_t)(uint8_t)string[3];
}

static kern_return_t ifans_smc_call(io_connect_t connection, IFansSMCKeyData *input, IFansSMCKeyData *output) {
    size_t outputSize = sizeof(*output);
    return IOConnectCallStructMethod(
        connection,
        IFANS_SMC_KERNEL_INDEX,
        input,
        sizeof(*input),
        output,
        &outputSize
    );
}

kern_return_t ifans_smc_open(void **handleOut) {
    if (handleOut == NULL) {
        return kIOReturnBadArgument;
    }

    *handleOut = NULL;

    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (service == IO_OBJECT_NULL) {
        return kIOReturnUnsupported;
    }

    IFansSMCHandle *handle = (IFansSMCHandle *)calloc(1, sizeof(IFansSMCHandle));
    if (handle == NULL) {
        IOObjectRelease(service);
        return kIOReturnNoMemory;
    }

    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, &handle->connection);
    IOObjectRelease(service);

    if (result != KERN_SUCCESS) {
        free(handle);
        return result;
    }

    *handleOut = handle;
    return KERN_SUCCESS;
}

void ifans_smc_close(void *rawHandle) {
    IFansSMCHandle *handle = (IFansSMCHandle *)rawHandle;
    if (handle == NULL) {
        return;
    }

    if (handle->connection != IO_OBJECT_NULL) {
        IOServiceClose(handle->connection);
    }
    free(handle);
}

kern_return_t ifans_smc_read(
    void *rawHandle,
    const char *key,
    uint32_t *dataTypeOut,
    uint32_t *dataSizeOut,
    uint8_t *bytesOut,
    uint32_t bytesCapacity
) {
    IFansSMCHandle *handle = (IFansSMCHandle *)rawHandle;
    if (handle == NULL || key == NULL || dataTypeOut == NULL || dataSizeOut == NULL || bytesOut == NULL) {
        return kIOReturnBadArgument;
    }

    IFansSMCKeyData input = {0};
    IFansSMCKeyData output = {0};

    input.key = ifans_smc_strtoul4(key);
    input.data8 = IFANS_SMC_CMD_READ_KEYINFO;

    kern_return_t result = ifans_smc_call(handle->connection, &input, &output);
    if (result != KERN_SUCCESS) {
        return result;
    }

    if (output.keyInfo.dataSize > bytesCapacity) {
        return kIOReturnNoSpace;
    }

    uint32_t dataType = output.keyInfo.dataType;
    uint32_t dataSize = output.keyInfo.dataSize;

    input.keyInfo.dataSize = dataSize;
    input.data8 = IFANS_SMC_CMD_READ_BYTES;

    result = ifans_smc_call(handle->connection, &input, &output);
    if (result != KERN_SUCCESS) {
        return result;
    }

    *dataTypeOut = dataType;
    *dataSizeOut = dataSize;
    memset(bytesOut, 0, bytesCapacity);
    memcpy(bytesOut, output.bytes, dataSize);
    return KERN_SUCCESS;
}

kern_return_t ifans_smc_write(void *rawHandle, const char *key, const uint8_t *bytes, uint32_t dataSize) {
    IFansSMCHandle *handle = (IFansSMCHandle *)rawHandle;
    if (handle == NULL || key == NULL || bytes == NULL || dataSize > sizeof(IFansSMCBytes)) {
        return kIOReturnBadArgument;
    }

    IFansSMCKeyData input = {0};
    IFansSMCKeyData output = {0};

    input.key = ifans_smc_strtoul4(key);
    input.data8 = IFANS_SMC_CMD_WRITE_BYTES;
    input.keyInfo.dataSize = dataSize;
    memcpy(input.bytes, bytes, dataSize);

    kern_return_t result = ifans_smc_call(handle->connection, &input, &output);
    if (result != KERN_SUCCESS) {
        return result;
    }

    if (output.result != 0x00) {
        return kIOReturnError;
    }

    return KERN_SUCCESS;
}
