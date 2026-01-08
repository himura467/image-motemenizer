class WasmBinding {
    constructor() {
        this.wasm = null;
        this.memory = null;
    }

    async init() {
        const source = await WebAssembly.instantiateStreaming(
            fetch('image_motemenizer.wasm')
        );
        this.wasm = source.instance.exports;
        this.memory = this.wasm.memory;
    }

    alloc(len) {
        return this.wasm.wasmAlloc(len);
    }

    free(ptr, len) {
        this.wasm.wasmFree(ptr, len);
    }

    write(bytes) {
        const len = bytes.length;
        const ptr = this.alloc(len);
        if (!ptr) {
            throw new Error('Failed to allocate memory in WASM');
        }

        const wasmView = new Uint8Array(this.memory.buffer, ptr, len);
        wasmView.set(bytes);

        return { ptr, len };
    }

    read(ptr, len) {
        const wasmView = new Uint8Array(this.memory.buffer, ptr, len);
        return new Uint8Array(wasmView);
    }

    applyMosaic(imageBytes, blocksWidth, blocksHeight, colorSpace = 'rgb', format = 'png') {
        // Map format string to integer (0=PNG, 1=JPG, 2=BMP)
        const formatMap = { 'png': 0, 'jpg': 1, 'jpeg': 1, 'bmp': 2 };
        const formatInt = formatMap[format.toLowerCase()];
        if (formatInt === undefined) {
            throw new Error(`Unsupported format '${format}'. Supported formats: png, jpg, jpeg, bmp`);
        }

        let input = null;
        let colorSpaceInput = null;
        let outputLenPtr = null;
        let outputPtr = null;
        let outputLen = 0;

        try {
            input = this.write(imageBytes);
            colorSpaceInput = this.write(new TextEncoder().encode(colorSpace));

            outputLenPtr = this.alloc(4);
            if (!outputLenPtr) {
                throw new Error('Failed to allocate output length pointer');
            }

            outputPtr = this.wasm.applyMosaic(
                input.ptr,
                input.len,
                blocksWidth,
                blocksHeight,
                colorSpaceInput.ptr,
                colorSpaceInput.len,
                formatInt,
                outputLenPtr
            );
            if (!outputPtr) {
                throw new Error('Failed to apply mosaic');
            }

            outputLen = new Uint32Array(this.memory.buffer, outputLenPtr, 1)[0];
            return this.read(outputPtr, outputLen);
        } finally {
            if (input) this.free(input.ptr, input.len);
            if (colorSpaceInput) this.free(colorSpaceInput.ptr, colorSpaceInput.len);
            if (outputLenPtr) this.free(outputLenPtr, 4);
            if (outputPtr) this.free(outputPtr, outputLen);
        }
    }

    getDimensions(imageBytes) {
        let input = null;
        let dimsPtr = null;

        try {
            input = this.write(imageBytes);

            dimsPtr = this.alloc(8);
            if (!dimsPtr) {
                throw new Error('Failed to allocate dimensions pointer');
            }

            const result = this.wasm.getDimensions(
                input.ptr,
                input.len,
                dimsPtr,
                dimsPtr + 4
            );
            if (result !== 0) {
                throw new Error('Failed to get image dimensions');
            }

            const dimsView = new Uint32Array(this.memory.buffer, dimsPtr, 2);
            return { width: dimsView[0], height: dimsView[1] };
        } finally {
            if (input) this.free(input.ptr, input.len);
            if (dimsPtr) this.free(dimsPtr, 8);
        }
    }

    getVersion() {
        const ptr = this.wasm.version();
        const view = new Uint8Array(this.memory.buffer, ptr);

        // Read null-terminated string
        let length = 0;
        while (view[length] !== 0) {
            length++;
        }

        const decoder = new TextDecoder();
        return decoder.decode(view.slice(0, length));
    }
}

window.wasmBinding = new WasmBinding();
