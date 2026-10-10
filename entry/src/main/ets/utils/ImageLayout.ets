import { CropLayout } from '../models/EditorModels';

const MAX_EXPORT_PIXELS: number = 16000000;
const MAX_EXPORT_EDGE: number = 4096;

export function ratioValue(ratio: string, sourceWidth: number, sourceHeight: number): number {
  if (ratio === '1:1') {
    return 1;
  }
  if (ratio === '4:5') {
    return 4 / 5;
  }
  if (ratio === '3:4') {
    return 3 / 4;
  }
  if (ratio === '9:16') {
    return 9 / 16;
  }
  return sourceWidth / sourceHeight;
}

export function calculateCropLayout(sourceWidth: number, sourceHeight: number,
  ratio: string, sizePercent: number): CropLayout {
  const targetRatio = ratioValue(ratio, sourceWidth, sourceHeight);
  const sourceRatio = sourceWidth / sourceHeight;
  let cropWidth = sourceWidth;
  let cropHeight = sourceHeight;
  let sourceX = 0;
  let sourceY = 0;

  if (sourceRatio > targetRatio) {
    cropWidth = Math.round(sourceHeight * targetRatio);
    sourceX = Math.round((sourceWidth - cropWidth) / 2);
  } else if (sourceRatio < targetRatio) {
    cropHeight = Math.round(sourceWidth / targetRatio);
    sourceY = Math.round((sourceHeight - cropHeight) / 2);
  }

  let outputWidth = Math.max(1, Math.round(cropWidth * sizePercent / 100));
  let outputHeight = Math.max(1, Math.round(cropHeight * sizePercent / 100));
  let scale = 1;
  if (outputWidth > MAX_EXPORT_EDGE || outputHeight > MAX_EXPORT_EDGE) {
    scale = Math.min(scale, MAX_EXPORT_EDGE / Math.max(outputWidth, outputHeight));
  }
  const pixels = outputWidth * outputHeight;
  if (pixels > MAX_EXPORT_PIXELS) {
    scale = Math.min(scale, Math.sqrt(MAX_EXPORT_PIXELS / pixels));
  }
  const wasLimited = scale < 0.999;
  if (wasLimited) {
    outputWidth = Math.max(1, Math.round(outputWidth * scale));
    outputHeight = Math.max(1, Math.round(outputHeight * scale));
  }
  return {
    sourceX: sourceX,
    sourceY: sourceY,
    sourceWidth: cropWidth,
    sourceHeight: cropHeight,
    outputWidth: outputWidth,
    outputHeight: outputHeight,
    wasLimited: wasLimited
  };
}

export function calculateAdjustedCropLayout(sourceWidth: number, sourceHeight: number,
  ratio: string, sizePercent: number, zoomValue: number, offsetXValue: number,
  offsetYValue: number): CropLayout {
  const base = calculateCropLayout(sourceWidth, sourceHeight, ratio, sizePercent);
  const zoom = Math.max(1, Math.min(3, zoomValue));
  const maxOffset = (zoom - 1) / 2;
  const offsetX = Math.max(-maxOffset, Math.min(maxOffset, offsetXValue));
  const offsetY = Math.max(-maxOffset, Math.min(maxOffset, offsetYValue));
  const cropWidth = base.sourceWidth / zoom;
  const cropHeight = base.sourceHeight / zoom;
  const centeredX = base.sourceX + (base.sourceWidth - cropWidth) / 2;
  const centeredY = base.sourceY + (base.sourceHeight - cropHeight) / 2;
  const sourceX = centeredX - offsetX * base.sourceWidth / zoom;
  const sourceY = centeredY - offsetY * base.sourceHeight / zoom;
  return {
    sourceX: Math.max(base.sourceX, Math.min(base.sourceX + base.sourceWidth - cropWidth, sourceX)),
    sourceY: Math.max(base.sourceY, Math.min(base.sourceY + base.sourceHeight - cropHeight, sourceY)),
    sourceWidth: cropWidth,
    sourceHeight: cropHeight,
    outputWidth: base.outputWidth,
    outputHeight: base.outputHeight,
    wasLimited: base.wasLimited
  };
}

export function orientationToDegrees(value: string): number {
  if (value === '6' || value === 'Right-top') {
    return 90;
  }
  if (value === '3' || value === 'Bottom-right') {
    return 180;
  }
  if (value === '8' || value === 'Left-bottom') {
    return 270;
  }
  return 0;
}
