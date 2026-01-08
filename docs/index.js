const upload = document.getElementById('upload');
const fileInput = document.getElementById('fileInput');
const control = document.getElementById('control');
const blocksWidthNumber = document.getElementById('blocksWidthNumber');
const blocksWidthRange = document.getElementById('blocksWidthRange');
const blocksHeightNumber = document.getElementById('blocksHeightNumber');
const blocksHeightRange = document.getElementById('blocksHeightRange');
const colorSpaces = document.getElementsByName('colorSpace');
const apply = document.getElementById('apply');
const preview = document.getElementById('preview');
const originalImage = document.getElementById('originalImage');
const processedImage = document.getElementById('processedImage');
const loading = document.getElementById('loading');
const download = document.getElementById('download');
const errorMessage = document.getElementById('errorMessage');

let image = null;

async function init() {
    try {
        showError('Loading WebAssembly module...');
        await window.wasmBinding.init();
        const version = window.wasmBinding.getVersion();
        console.log('Loaded image-motemenizer version: ', version);
        hideError();
    } catch (error) {
        showError('Failed to load WebAssembly module. Please refresh the page.');
        console.error(error);
    }
}

upload.addEventListener('click', () => fileInput.click());

upload.addEventListener('dragover', (e) => {
    e.preventDefault();
    upload.classList.add('dragover');
});

upload.addEventListener('dragleave', () => {
    upload.classList.remove('dragover');
});

upload.addEventListener('drop', (e) => {
    e.preventDefault();
    upload.classList.remove('dragover');
    if (e.dataTransfer.files.length > 0) {
        handleFile(e.dataTransfer.files[0]);
    }
});

fileInput.addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
        handleFile(e.target.files[0]);
    }
});

blocksWidthNumber.addEventListener('input', (e) => {
    blocksWidthRange.value = e.target.value;
});

blocksWidthRange.addEventListener('input', (e) => {
    blocksWidthNumber.value = e.target.value;
});

blocksHeightNumber.addEventListener('input', (e) => {
    blocksHeightRange.value = e.target.value;
});

blocksHeightRange.addEventListener('input', (e) => {
    blocksHeightNumber.value = e.target.value;
});

apply.addEventListener('click', processImage);

download.addEventListener('click', downloadResult);

async function handleFile(file) {
    if (!file.type.match(/image\/(png|jpg|jpeg|bmp)/)) {
        showError('Please upload a PNG, JPG, or BMP image.');
        return;
    }

    try {
        const buffer = await file.arrayBuffer();
        image = new Uint8Array(buffer);

        const blob = new Blob([image], { type: file.type });
        const url = URL.createObjectURL(blob);
        originalImage.src = url;

        control.style.display = 'block';
        preview.style.display = 'block';
        processedImage.style.display = 'none';
        download.style.display = 'none';

        hideError();
    } catch (error) {
        showError('Failed to load image: ' + error.message);
        console.error(error);
    }
}

async function processImage() {
    if (!image) {
        showError('Please upload an image first.');
        return;
    }

    try {
        apply.disabled = true;
        processedImage.style.display = 'none';
        loading.style.display = 'block';
        download.style.display = 'none';
        hideError();

        const width = parseInt(blocksWidthNumber.value);
        const height = parseInt(blocksHeightNumber.value);
        const colorSpace = Array.from(colorSpaces).find(radio => radio.checked).value;

        const result = window.wasmBinding.applyMosaic(
            image,
            width,
            height,
            colorSpace,
            'png'
        );

        const blob = new Blob([result], { type: 'image/png' });
        const url = URL.createObjectURL(blob);
        processedImage.src = url;
        processedImage.style.display = 'block';
        download.style.display = 'block';

        // Store result for download
        processedImage.dataset.resultBlob = url;
    } catch (error) {
        showError('Failed to process image: ' + error.message);
        console.error(error);
    } finally {
        apply.disabled = false;
        loading.style.display = 'none';
    }
}

function downloadResult() {
    const url = processedImage.dataset.resultBlob;
    if (!url) {
        showError('No processed image to download.');
        return;
    }

    const a = document.createElement('a');
    a.href = url;
    a.download = 'motemenized.png';

    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
}

function showError(message) {
    errorMessage.textContent = message;
    errorMessage.style.display = 'block';
}

function hideError() {
    errorMessage.style.display = 'none';
}

document.addEventListener('DOMContentLoaded', init);
