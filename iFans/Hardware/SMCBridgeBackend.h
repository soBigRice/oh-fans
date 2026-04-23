#ifndef IFANS_SMCBRIDGEBACKEND_H
#define IFANS_SMCBRIDGEBACKEND_H

#include <IOKit/IOKitLib.h>
#include <stdint.h>

kern_return_t ifans_smc_open(void **handleOut);
void ifans_smc_close(void *rawHandle);
kern_return_t ifans_smc_read(
    void *rawHandle,
    const char *key,
    uint32_t *dataTypeOut,
    uint32_t *dataSizeOut,
    uint8_t *bytesOut,
    uint32_t bytesCapacity
);
kern_return_t ifans_smc_write(void *rawHandle, const char *key, const uint8_t *bytes, uint32_t dataSize);

#endif
