export interface ExportOptions {
  sourceUri: string;
  style: string;
  ratio: string;
  sizePercent: number;
  jpegQuality: number;
  caption: string;
  deviceModel: string;
  shootingDate: string;
  locationText: string;
  showDevice: boolean;
  showDate: boolean;
  showLocation: boolean;
  markOpacity: number;
  photoZoom: number;
  photoOffsetX: number;
  photoOffsetY: number;
  markPositionX: number;
  markPositionY: number;
  markScale: number;
}

export interface ExportResult {
  targetUri: string;
  previewUri: string;
  previewPath: string;
  width: number;
  height: number;
  wasLimited: boolean;
}

export interface PixelSize {
  width: number;
  height: number;
}

export interface CropLayout {
  sourceX: number;
  sourceY: number;
  sourceWidth: number;
  sourceHeight: number;
  outputWidth: number;
  outputHeight: number;
  wasLimited: boolean;
}

export interface EditorSnapshot {
  style: string;
  ratio: string;
  caption: string;
  showDevice: boolean;
  showDate: boolean;
  showLocation: boolean;
  markOpacity: number;
  photoZoom: number;
  photoOffsetX: number;
  photoOffsetY: number;
  markPositionX: number;
  markPositionY: number;
  markScale: number;
}
