import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import common from '@ohos.app.ability.common';
import { LengthMetricsUnit } from '@kit.ArkUI';
import { ExportOptions, ExportResult, CropLayout } from '../models/EditorModels';
import { calculateAdjustedCropLayout, orientationToDegrees } from '../utils/ImageLayout';
import { getTemplateConfig, TemplateConfig } from '../models/TemplateCatalog';

interface CompositeResult {
  pixelMap: image.PixelMap;
  layout: CropLayout;
}

export class PhotoExportService {
  private static writeData(path: string, data: ArrayBuffer, mode: number): void {
    let output: fs.File | undefined = undefined;
    try {
      output = fs.openSync(path, mode);
      fs.writeSync(output.fd, data);
    } catch (err) {
      throw new Error('图片文件写入失败');
    } finally {
      if (output !== undefined) {
        try {
          fs.closeSync(output);
        } catch (err) {
        }
      }
    }
  }

  private static fitText(context: OffscreenCanvasRenderingContext2D, value: string, maxWidth: number): string {
    if (context.measureText(value).width <= maxWidth) {
      return value;
    }
    let result = value;
    while (result.length > 1 && context.measureText(`${result}…`).width > maxWidth) {
      result = result.substring(0, result.length - 1);
    }
    return `${result}…`;
  }

  private static async savePreview(context: common.UIAbilityContext, pixelMap: image.PixelMap,
    width: number, height: number): Promise<string> {
    const previewWidth = Math.min(480, width);
    const previewHeight = Math.max(1, Math.round(height * previewWidth / width));
    const canvas = new OffscreenCanvas(previewWidth, previewHeight, LengthMetricsUnit.PX);
    const drawing = canvas.getContext('2d', { antialias: true });
    drawing.drawImage(pixelMap, 0, 0, width, height, 0, 0, previewWidth, previewHeight);
    const previewPixelMap = drawing.getPixelMap(0, 0, previewWidth, previewHeight);
    const previewPacker = image.createImagePacker();
    try {
      const data = await previewPacker.packToData(previewPixelMap, { format: 'image/jpeg', quality: 82 });
      const directory = `${context.filesDir}/work_previews`;
      try {
        fs.mkdirSync(directory);
      } catch (err) {
      }
      const path = `${directory}/preview_${Date.now()}_${Math.round(Math.random() * 10000)}.jpg`;
      PhotoExportService.writeData(path, data,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      return path;
    } catch (err) {
      throw new Error('作品缩略图生成失败');
    } finally {
      previewPixelMap.release();
      await previewPacker.release();
    }
  }

  static deleteLocalPreview(path: string): void {
    if (path.length === 0) {
      return;
    }
    try {
      fs.unlinkSync(path);
    } catch (err) {
    }
  }

  private static drawTextBlock(context: OffscreenCanvasRenderingContext2D, options: ExportOptions,
    x: number, y: number, width: number, height: number, config: TemplateConfig): void {
    const padding = Math.round(width * 0.035);
    const titleSize = Math.max(16, Math.round(width * 0.025));
    const smallSize = Math.max(12, Math.round(width * 0.017));
    const leftWidth = width * 0.55;

    context.textBaseline = 'top';
    context.textAlign = 'left';
    context.fillStyle = config.primaryColor;
    context.font = `bold ${titleSize}px sans-serif`;
    context.fillText('相片纸 · PHOTO PAPER', x + padding, y + padding);
    context.fillStyle = config.secondaryColor;
    context.font = `${smallSize}px sans-serif`;
    const deviceSuffix = options.showDevice ? ` · ${options.deviceModel}` : '';
    const caption = options.style === 'theme' ? 'TRAVEL TICKET · NANJING' : `${options.caption}${deviceSuffix}`;
    context.fillText(PhotoExportService.fitText(context, caption, leftWidth), x + padding,
      y + padding + titleSize * 1.5);

    context.textAlign = 'right';
    context.fillStyle = config.primaryColor;
    if (options.showDate) {
      context.font = `bold ${smallSize}px sans-serif`;
      context.fillText(PhotoExportService.fitText(context, options.shootingDate, width * 0.36),
        x + width - padding, y + padding);
    }
    if (options.showLocation) {
      context.fillStyle = config.secondaryColor;
      context.font = `${smallSize}px sans-serif`;
      context.fillText(PhotoExportService.fitText(context, options.locationText, width * 0.36),
        x + width - padding, y + padding + titleSize * 1.5);
    }
  }

  private static drawTemplate(context: OffscreenCanvasRenderingContext2D, options: ExportOptions,
    width: number, height: number): void {
    const config = getTemplateConfig(options.style);
    const scale = Math.max(0.62, Math.min(1, options.markScale));
    const markWidth = Math.round(width * scale * 0.94);
    const markHeight = Math.max(Math.round(height * 0.12 * scale), Math.round(markWidth * 0.115));
    const availableX = Math.max(0, width - markWidth);
    const availableY = Math.max(0, height - markHeight);
    const x = Math.round(availableX * (Math.max(-1, Math.min(1, options.markPositionX)) + 1) / 2);
    const y = Math.round(availableY * (Math.max(-1, Math.min(1, options.markPositionY)) + 1) / 2);
    if (options.style === 'glass') {
      const opacity = Math.max(0.3, Math.min(1, options.markOpacity / 100));
      context.fillStyle = `rgba(15, 26, 35, ${opacity})`;
    } else {
      context.fillStyle = config.backgroundColor;
    }
    context.fillRect(x, y, markWidth, markHeight);
    context.strokeStyle = config.borderColor;
    context.lineWidth = Math.max(1, Math.round(width * 0.0015));
    context.strokeRect(x, y, markWidth, markHeight);
    if (config.dashed) {
      const headerSize = Math.max(12, Math.round(markWidth * 0.016));
      const padding = Math.round(markWidth * 0.035);
      context.textBaseline = 'top';
      context.fillStyle = config.primaryColor;
      context.font = `bold ${headerSize}px sans-serif`;
      context.textAlign = 'left';
      context.fillText('TRAVEL NOTE', x + padding, y + padding);
      context.textAlign = 'right';
      context.fillStyle = config.secondaryColor;
      context.font = `${headerSize}px sans-serif`;
      context.fillText('NO. 0826', x + markWidth - padding, y + padding);
      context.strokeStyle = config.borderColor;
      context.lineWidth = Math.max(2, Math.round(width * 0.002));
      context.setLineDash([Math.round(width * 0.012), Math.round(width * 0.008)]);
      context.beginPath();
      context.moveTo(x + Math.round(markWidth * 0.035), y + Math.round(markHeight * 0.25));
      context.lineTo(x + markWidth - Math.round(markWidth * 0.035), y + Math.round(markHeight * 0.25));
      context.stroke();
      context.setLineDash([]);
      PhotoExportService.drawTextBlock(context, options, x, y + Math.round(markHeight * 0.28),
        markWidth, Math.round(markHeight * 0.72), config);
      return;
    }
    PhotoExportService.drawTextBlock(context, options, x, y, markWidth, markHeight, config);
  }

  private static async createComposite(options: ExportOptions): Promise<CompositeResult> {
    const source = image.createImageSource(options.sourceUri);
    let decoded: image.PixelMap | undefined = undefined;
    try {
      const info = await source.getImageInfo();
      let orientationValue = '1';
      try {
        orientationValue = await source.getImageProperty(image.PropertyKey.ORIENTATION);
      } catch (err) {
        orientationValue = '1';
      }
      const angle = orientationToDegrees(orientationValue);
      const orientedWidth = angle === 90 || angle === 270 ? info.size.height : info.size.width;
      const orientedHeight = angle === 90 || angle === 270 ? info.size.width : info.size.height;
      const preliminary = calculateAdjustedCropLayout(orientedWidth, orientedHeight, options.ratio,
        options.sizePercent, options.photoZoom, options.photoOffsetX, options.photoOffsetY);
      const decodeScale = Math.min(1, preliminary.outputWidth / preliminary.sourceWidth);
      const decodeWidth = Math.max(1, Math.round(info.size.width * decodeScale));
      const decodeHeight = Math.max(1, Math.round(info.size.height * decodeScale));
      decoded = await source.createPixelMap({
        desiredSize: { width: decodeWidth, height: decodeHeight },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      });
      if (angle !== 0) {
        await decoded.rotate(angle);
      }
      const decodedInfo = await decoded.getImageInfo();
      const layout = calculateAdjustedCropLayout(decodedInfo.size.width, decodedInfo.size.height, options.ratio,
        100, options.photoZoom, options.photoOffsetX, options.photoOffsetY);
      layout.outputWidth = preliminary.outputWidth;
      layout.outputHeight = preliminary.outputHeight;
      const canvas = new OffscreenCanvas(layout.outputWidth, layout.outputHeight, LengthMetricsUnit.PX);
      const context = canvas.getContext('2d', { antialias: true });
      context.drawImage(decoded, layout.sourceX, layout.sourceY, layout.sourceWidth, layout.sourceHeight,
        0, 0, layout.outputWidth, layout.outputHeight);
      PhotoExportService.drawTemplate(context, options, layout.outputWidth, layout.outputHeight);
      const result = context.getPixelMap(0, 0, layout.outputWidth, layout.outputHeight);
      layout.wasLimited = preliminary.wasLimited;
      const composite: CompositeResult = { pixelMap: result, layout: layout };
      return composite;
    } finally {
      if (decoded !== undefined) {
        decoded.release();
      }
      await source.release();
    }
  }

  static async exportToGallery(context: common.UIAbilityContext, options: ExportOptions): Promise<ExportResult> {
    const composite = await PhotoExportService.createComposite(options);
    const packer = image.createImagePacker();
    let helper: photoAccessHelper.PhotoAccessHelper | undefined = undefined;
    try {
      const jpeg = await packer.packToData(composite.pixelMap, {
        format: 'image/jpeg',
        quality: options.jpegQuality
      });
      const tempPath = `${context.cacheDir}/photopaper_original_export.jpg`;
      PhotoExportService.writeData(tempPath, jpeg,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);

      helper = photoAccessHelper.getPhotoAccessHelper(context);
      const sourceUri = fileUri.getUriFromPath(tempPath);
      const config: photoAccessHelper.PhotoCreationConfig = {
        title: `相片纸_${Date.now()}`,
        fileNameExtension: 'jpg',
        photoType: photoAccessHelper.PhotoType.IMAGE
      };
      const targets = await helper.showAssetsCreationDialog([sourceUri], [config]);
      if (targets.length === 0) {
        return {
          targetUri: '',
          previewUri: '',
          previewPath: '',
          width: composite.layout.outputWidth,
          height: composite.layout.outputHeight,
          wasLimited: composite.layout.wasLimited
        };
      }
      PhotoExportService.writeData(targets[0], jpeg, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      let previewPath = '';
      try {
        previewPath = await PhotoExportService.savePreview(context, composite.pixelMap,
          composite.layout.outputWidth, composite.layout.outputHeight);
      } catch (err) {
        previewPath = '';
      }
      return {
        targetUri: targets[0],
        previewUri: previewPath.length > 0 ? fileUri.getUriFromPath(previewPath) : targets[0],
        previewPath: previewPath,
        width: composite.layout.outputWidth,
        height: composite.layout.outputHeight,
        wasLimited: composite.layout.wasLimited
      };
    } catch (err) {
      throw new Error('原图导出失败，请重试');
    } finally {
      composite.pixelMap.release();
      await packer.release();
      if (helper !== undefined) {
        try {
          await helper.release();
        } catch (err) {
        }
      }
    }
  }
}
