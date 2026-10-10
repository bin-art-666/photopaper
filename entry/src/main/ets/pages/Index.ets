import photoAccessHelper from '@ohos.file.photoAccessHelper';
import image from '@ohos.multimedia.image';
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { PhotoExportService } from '../services/PhotoExportService';
import { EditorSnapshot, ExportOptions } from '../models/EditorModels';
import { getTemplateConfig, TEMPLATE_CONFIGS, TemplateConfig } from '../models/TemplateCatalog';
import { DraftRecord, ProjectState, WorkRecord } from '../models/LibraryModels';
import { LibraryRepository, upsertDraft } from '../services/LibraryRepository';

@Entry
@Component
struct Index {
  @State page: string = 'home';
  @State tab: string = 'home';
  @State style: string = 'glass';
  @State ratio: string = 'original';
  @State exportLabel: string = '导出图片';
  @State selectedUri: string = '';
  @State selectedSize: string = '演示图片';
  @State deviceModel: string = 'Harmony Device';
  @State shootingDate: string = '2026:08:26 05:48:00';
  @State locationText: string = '31°57′ N  ·  118°46′ E';
  @State caption: string = '今天也值得被好好收藏';
  @State quality: string = 'high';
  @State exportSize: string = '100';
  @State showDevice: boolean = true;
  @State showDate: boolean = true;
  @State showLocation: boolean = true;
  @State markOpacity: number = 72;
  @State photoZoom: number = 1;
  @State photoOffsetX: number = 0;
  @State photoOffsetY: number = 0;
  @State markPositionX: number = 0;
  @State markPositionY: number = 0.82;
  @State markScale: number = 0.92;
  @State editTarget: string = 'photo';
  @State previewWidth: number = 328;
  @State previewHeight: number = 360;
  private gestureStartX: number = 0;
  private gestureStartY: number = 0;
  private gestureStartScale: number = 1;
  @State creationCount: number = 0;
  @State favoriteStyle: string = 'glass';
  @State isExporting: boolean = false;
  @State notice: string = '';
  @State undoStack: string[] = [];
  @State redoStack: string[] = [];
  @State lastExport: string = '暂无导出记录';
  @State works: WorkRecord[] = [];
  @State drafts: DraftRecord[] = [];
  @State libraryTab: string = 'works';
  @State activeDraftId: string = '';
  @State selectedWorkId: string = '';

  aboutToAppear(): void {
    this.bootstrap().catch(() => {
      this.notice = '本地设置读取失败，将使用默认配置';
    });
  }

  private async bootstrap(): Promise<void> {
    await this.loadSettings();
    await this.loadLibrary();
  }

  private getAbilityContext(): common.UIAbilityContext {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      throw new Error('UIAbility context is unavailable');
    }
    return context as common.UIAbilityContext;
  }

  private async loadSettings(): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.getAbilityContext(), 'photopaper_settings');
      this.style = await store.get('style', 'glass') as string;
      this.ratio = await store.get('ratio', 'original') as string;
      this.quality = await store.get('quality', 'high') as string;
      this.exportSize = await store.get('exportSize', '100') as string;
      this.caption = await store.get('caption', '今天也值得被好好收藏') as string;
      this.creationCount = await store.get('creationCount', 0) as number;
      this.favoriteStyle = await store.get('favoriteStyle', 'glass') as string;
      this.showDevice = await store.get('showDevice', true) as boolean;
      this.showDate = await store.get('showDate', true) as boolean;
      this.showLocation = await store.get('showLocation', true) as boolean;
      this.markOpacity = await store.get('markOpacity', 72) as number;
      this.photoZoom = await store.get('photoZoom', 1) as number;
      this.photoOffsetX = await store.get('photoOffsetX', 0) as number;
      this.photoOffsetY = await store.get('photoOffsetY', 0) as number;
      this.markPositionX = await store.get('markPositionX', 0) as number;
      this.markPositionY = await store.get('markPositionY', 0.82) as number;
      this.markScale = await store.get('markScale', 0.92) as number;
      this.lastExport = await store.get('lastExport', '暂无导出记录') as string;
      this.selectedUri = await store.get('draftUri', '') as string;
      if (this.selectedUri.length > 0) {
        try {
          await this.readPhotoInfo(this.selectedUri);
        } catch (err) {
          this.selectedUri = '';
        }
      }
    } catch (err) {
      this.notice = '本地设置读取失败，将使用默认配置';
    }
  }

  private async saveSettings(includeDraft: boolean = false): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.getAbilityContext(), 'photopaper_settings');
      await store.put('style', this.style);
      await store.put('ratio', this.ratio);
      await store.put('quality', this.quality);
      await store.put('exportSize', this.exportSize);
      await store.put('caption', this.caption);
      await store.put('creationCount', this.creationCount);
      await store.put('favoriteStyle', this.favoriteStyle);
      await store.put('showDevice', this.showDevice);
      await store.put('showDate', this.showDate);
      await store.put('showLocation', this.showLocation);
      await store.put('markOpacity', this.markOpacity);
      await store.put('photoZoom', this.photoZoom);
      await store.put('photoOffsetX', this.photoOffsetX);
      await store.put('photoOffsetY', this.photoOffsetY);
      await store.put('markPositionX', this.markPositionX);
      await store.put('markPositionY', this.markPositionY);
      await store.put('markScale', this.markScale);
      await store.put('lastExport', this.lastExport);
      if (includeDraft) {
        await store.put('draftUri', this.selectedUri);
      }
      await store.flush();
    } catch (err) {
      this.notice = '本地设置暂时无法保存';
    }
  }

  private async choosePhoto(): Promise<void> {
    this.notice = '';
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      options.isOriginalSupported = true;
      options.isPhotoTakingSupported = true;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      if (result.photoUris.length === 0) {
        return;
      }
      this.selectedUri = result.photoUris[0];
      this.activeDraftId = '';
      this.resetTransform(false);
      await this.readPhotoInfo(this.selectedUri);
      this.page = 'editor';
      await this.saveSettings(true);
    } catch (err) {
      this.notice = '没有选中照片，请重试';
    }
  }

  private async readPhotoInfo(uri: string): Promise<void> {
    const source = image.createImageSource(uri);
    try {
      const info = await source.getImageInfo();
      this.selectedSize = `${info.size.width} × ${info.size.height}`;
      try {
        this.deviceModel = await source.getImageProperty(image.PropertyKey.MODEL);
      } catch (err) {
        this.deviceModel = 'Harmony Device';
      }
      try {
        this.shootingDate = await source.getImageProperty(image.PropertyKey.DATE_TIME_ORIGINAL);
      } catch (err) {
        this.shootingDate = '拍摄时间未记录';
      }
      try {
        const latitude = await source.getImageProperty(image.PropertyKey.GPS_LATITUDE);
        const longitude = await source.getImageProperty(image.PropertyKey.GPS_LONGITUDE);
        this.locationText = `${latitude}  ·  ${longitude}`;
      } catch (err) {
        this.locationText = '地点未记录';
      }
    } finally {
      await source.release();
    }
  }

  private async saveDraft(): Promise<void> {
    if (this.selectedUri.length === 0) {
      this.notice = '请先选择一张照片';
      return;
    }
    const now = Date.now();
    if (this.activeDraftId.length === 0) {
      this.activeDraftId = `draft_${now}_${Math.round(Math.random() * 10000)}`;
    }
    const draft: DraftRecord = {
      id: this.activeDraftId,
      updatedAt: now,
      title: this.caption.length > 0 ? this.caption : '未命名相片纸',
      state: this.makeProjectState()
    };
    this.drafts = await LibraryRepository.saveDrafts(this.getAbilityContext(), upsertDraft(this.drafts, draft));
    await this.saveSettings(true);
    this.notice = `草稿已保存 · 共 ${this.drafts.length} 份`;
  }

  private async saveDraftAsNew(): Promise<void> {
    this.activeDraftId = '';
    await this.saveDraft();
    this.notice = `已另存为新草稿 · 共 ${this.drafts.length} 份`;
  }

  private makeProjectState(): ProjectState {
    return {
      sourceUri: this.selectedUri, selectedSize: this.selectedSize,
      deviceModel: this.deviceModel, shootingDate: this.shootingDate, locationText: this.locationText,
      style: this.style, ratio: this.ratio, quality: this.quality, exportSize: this.exportSize,
      caption: this.caption, showDevice: this.showDevice, showDate: this.showDate,
      showLocation: this.showLocation, markOpacity: this.markOpacity, photoZoom: this.photoZoom,
      photoOffsetX: this.photoOffsetX, photoOffsetY: this.photoOffsetY,
      markPositionX: this.markPositionX, markPositionY: this.markPositionY, markScale: this.markScale
    };
  }

  private applyProjectState(state: ProjectState): void {
    this.selectedUri = state.sourceUri;
    this.selectedSize = state.selectedSize;
    this.deviceModel = state.deviceModel;
    this.shootingDate = state.shootingDate;
    this.locationText = state.locationText;
    this.style = state.style;
    this.ratio = state.ratio;
    this.quality = state.quality;
    this.exportSize = state.exportSize;
    this.caption = state.caption;
    this.showDevice = state.showDevice;
    this.showDate = state.showDate;
    this.showLocation = state.showLocation;
    this.markOpacity = state.markOpacity;
    this.photoZoom = state.photoZoom;
    this.photoOffsetX = state.photoOffsetX;
    this.photoOffsetY = state.photoOffsetY;
    this.markPositionX = state.markPositionX;
    this.markPositionY = state.markPositionY;
    this.markScale = state.markScale;
    this.undoStack = [];
    this.redoStack = [];
  }

  private async loadLibrary(): Promise<void> {
    this.works = await LibraryRepository.loadWorks(this.getAbilityContext());
    this.drafts = await LibraryRepository.loadDrafts(this.getAbilityContext());
    if (this.drafts.length === 0 && this.selectedUri.length > 0) {
      const migrated: DraftRecord = {
        id: `migrated_${Date.now()}`,
        updatedAt: Date.now(),
        title: this.caption.length > 0 ? this.caption : '上次编辑',
        state: this.makeProjectState()
      };
      this.drafts = await LibraryRepository.saveDrafts(this.getAbilityContext(), [migrated]);
    }
  }

  private async openDraft(draft: DraftRecord): Promise<void> {
    this.applyProjectState(draft.state);
    this.activeDraftId = draft.id;
    try {
      await this.readPhotoInfo(this.selectedUri);
      this.page = 'editor';
      this.notice = '草稿已恢复';
    } catch (err) {
      this.notice = '原照片访问权限已失效，请重新选择照片';
    }
  }

  private async editWork(work: WorkRecord): Promise<void> {
    this.applyProjectState(work.state);
    this.activeDraftId = '';
    try {
      await this.readPhotoInfo(this.selectedUri);
      this.page = 'editor';
      this.notice = '已载入作品参数，可再次编辑';
    } catch (err) {
      this.notice = '原照片访问权限已失效，请重新选择照片';
    }
  }

  private async deleteDraft(id: string): Promise<void> {
    const remaining: DraftRecord[] = [];
    this.drafts.forEach((item: DraftRecord) => {
      if (item.id !== id) {
        remaining.push(item);
      }
    });
    this.drafts = await LibraryRepository.saveDrafts(this.getAbilityContext(), remaining);
    if (this.activeDraftId === id) {
      this.activeDraftId = '';
    }
    this.notice = '草稿已删除';
  }

  private async deleteWork(id: string): Promise<void> {
    const remaining: WorkRecord[] = [];
    this.works.forEach((item: WorkRecord) => {
      if (item.id !== id) {
        remaining.push(item);
      } else if (item.previewPath !== undefined) {
        PhotoExportService.deleteLocalPreview(item.previewPath);
      }
    });
    this.works = await LibraryRepository.saveWorks(this.getAbilityContext(), remaining);
    this.selectedWorkId = '';
    this.page = 'profile';
    this.notice = '作品记录已移除，相册中的图片不受影响';
  }

  private findSelectedWork(): WorkRecord | undefined {
    for (let index = 0; index < this.works.length; index++) {
      if (this.works[index].id === this.selectedWorkId) {
        return this.works[index];
      }
    }
    return undefined;
  }

  private showWorkDetail(work: WorkRecord): void {
    this.selectedWorkId = work.id;
    this.page = 'workDetail';
  }

  private selectedWorkUri(): string {
    const work = this.findSelectedWork();
    if (work === undefined) {
      return '';
    }
    return work.previewUri !== undefined && work.previewUri.length > 0 ? work.previewUri : work.outputUri;
  }

  private selectedWorkTitle(): string {
    const work = this.findSelectedWork();
    return work === undefined ? '作品已不存在' : work.title;
  }

  private selectedWorkInfo(): string {
    const work = this.findSelectedWork();
    if (work === undefined) {
      return '';
    }
    return `${new Date(work.createdAt).toLocaleString()} · ${work.width} × ${work.height} · ${getTemplateConfig(work.state.style).label}`;
  }

  private async editSelectedWork(): Promise<void> {
    const work = this.findSelectedWork();
    if (work !== undefined) {
      await this.editWork(work);
    }
  }

  private rememberEditorState(): void {
    const snapshot: EditorSnapshot = {
      style: this.style, ratio: this.ratio, caption: this.caption,
      showDevice: this.showDevice, showDate: this.showDate, showLocation: this.showLocation,
      markOpacity: this.markOpacity, photoZoom: this.photoZoom,
      photoOffsetX: this.photoOffsetX, photoOffsetY: this.photoOffsetY,
      markPositionX: this.markPositionX, markPositionY: this.markPositionY, markScale: this.markScale
    };
    const current = JSON.stringify(snapshot);
    const history = this.undoStack.slice();
    if (history.length === 0 || history[history.length - 1] !== current) {
      history.push(current);
      if (history.length > 20) {
        history.shift();
      }
    }
    this.undoStack = history;
    this.redoStack = [];
  }

  private applyEditorState(state: string): void {
    const snapshot = JSON.parse(state) as EditorSnapshot;
    this.style = snapshot.style;
    this.ratio = snapshot.ratio;
    this.caption = snapshot.caption;
    this.showDevice = snapshot.showDevice;
    this.showDate = snapshot.showDate;
    this.showLocation = snapshot.showLocation;
    this.markOpacity = snapshot.markOpacity;
    this.photoZoom = snapshot.photoZoom;
    this.photoOffsetX = snapshot.photoOffsetX;
    this.photoOffsetY = snapshot.photoOffsetY;
    this.markPositionX = snapshot.markPositionX;
    this.markPositionY = snapshot.markPositionY;
    this.markScale = snapshot.markScale;
  }

  private clamp(value: number, minimum: number, maximum: number): number {
    return Math.max(minimum, Math.min(maximum, value));
  }

  private normalizePhotoOffsets(): void {
    const maximum = (this.photoZoom - 1) / 2;
    this.photoOffsetX = this.clamp(this.photoOffsetX, -maximum, maximum);
    this.photoOffsetY = this.clamp(this.photoOffsetY, -maximum, maximum);
  }

  private resetTransform(recordHistory: boolean = true): void {
    if (recordHistory) {
      this.rememberEditorState();
    }
    this.photoZoom = 1;
    this.photoOffsetX = 0;
    this.photoOffsetY = 0;
    this.markPositionX = 0;
    this.markPositionY = 0.82;
    this.markScale = getTemplateConfig(this.style).defaultScale;
    this.saveSettings(false).catch(() => {});
  }

  private beginPan(): void {
    this.rememberEditorState();
    this.gestureStartX = this.editTarget === 'photo' ? this.photoOffsetX : this.markPositionX;
    this.gestureStartY = this.editTarget === 'photo' ? this.photoOffsetY : this.markPositionY;
  }

  private updatePan(event: GestureEvent): void {
    if (this.editTarget === 'photo') {
      const maximum = (this.photoZoom - 1) / 2;
      this.photoOffsetX = this.clamp(this.gestureStartX + event.offsetX / this.previewWidth, -maximum, maximum);
      this.photoOffsetY = this.clamp(this.gestureStartY + event.offsetY / this.previewHeight, -maximum, maximum);
    } else {
      this.markPositionX = this.clamp(this.gestureStartX + event.offsetX * 2 / this.previewWidth, -1, 1);
      this.markPositionY = this.clamp(this.gestureStartY + event.offsetY * 2 / this.previewHeight, -1, 1);
    }
  }

  private beginPinch(): void {
    this.rememberEditorState();
    this.gestureStartScale = this.editTarget === 'photo' ? this.photoZoom : this.markScale;
  }

  private updatePinch(event: GestureEvent): void {
    if (this.editTarget === 'photo') {
      this.photoZoom = this.clamp(this.gestureStartScale * event.scale, 1, 3);
      this.normalizePhotoOffsets();
    } else {
      this.markScale = this.clamp(this.gestureStartScale * event.scale, 0.62, 1);
    }
  }

  private undoEdit(): void {
    if (this.undoStack.length === 0) {
      this.notice = '没有可撤销的修改';
      return;
    }
    const undoHistory = this.undoStack.slice();
    const target = undoHistory.pop();
    const redoHistory = this.redoStack.slice();
    const currentSnapshot: EditorSnapshot = {
      style: this.style, ratio: this.ratio, caption: this.caption,
      showDevice: this.showDevice, showDate: this.showDate, showLocation: this.showLocation,
      markOpacity: this.markOpacity, photoZoom: this.photoZoom,
      photoOffsetX: this.photoOffsetX, photoOffsetY: this.photoOffsetY,
      markPositionX: this.markPositionX, markPositionY: this.markPositionY, markScale: this.markScale
    };
    redoHistory.push(JSON.stringify(currentSnapshot));
    this.undoStack = undoHistory;
    this.redoStack = redoHistory;
    if (target !== undefined) {
      this.applyEditorState(target);
    }
    this.saveSettings(false).catch(() => {});
    this.notice = '已撤销上一步修改';
  }

  private redoEdit(): void {
    if (this.redoStack.length === 0) {
      this.notice = '没有可恢复的修改';
      return;
    }
    const redoHistory = this.redoStack.slice();
    const target = redoHistory.pop();
    const undoHistory = this.undoStack.slice();
    const currentSnapshot: EditorSnapshot = {
      style: this.style, ratio: this.ratio, caption: this.caption,
      showDevice: this.showDevice, showDate: this.showDate, showLocation: this.showLocation,
      markOpacity: this.markOpacity, photoZoom: this.photoZoom,
      photoOffsetX: this.photoOffsetX, photoOffsetY: this.photoOffsetY,
      markPositionX: this.markPositionX, markPositionY: this.markPositionY, markScale: this.markScale
    };
    undoHistory.push(JSON.stringify(currentSnapshot));
    this.redoStack = redoHistory;
    this.undoStack = undoHistory;
    if (target !== undefined) {
      this.applyEditorState(target);
    }
    this.saveSettings(false).catch(() => {});
    this.notice = '已恢复修改';
  }

  private async exportPhoto(): Promise<void> {
    if (this.isExporting) {
      return;
    }
    if (this.selectedUri.length === 0) {
      this.notice = '请先从系统相册选择一张真实照片';
      return;
    }
    this.isExporting = true;
    this.exportLabel = '正在处理原图…';
    this.notice = '';
    try {
      const options: ExportOptions = {
        sourceUri: this.selectedUri,
        style: this.style,
        ratio: this.ratio,
        sizePercent: Number(this.exportSize),
        jpegQuality: this.quality === 'high' ? 98 : 88,
        caption: this.caption,
        deviceModel: this.deviceModel,
        shootingDate: this.shootingDate,
        locationText: this.locationText,
        showDevice: this.showDevice,
        showDate: this.showDate,
        showLocation: this.showLocation,
        markOpacity: this.markOpacity,
        photoZoom: this.photoZoom,
        photoOffsetX: this.photoOffsetX,
        photoOffsetY: this.photoOffsetY,
        markPositionX: this.markPositionX,
        markPositionY: this.markPositionY,
        markScale: this.markScale
      };
      const result = await PhotoExportService.exportToGallery(this.getAbilityContext(), options);
      if (result.targetUri.length === 0) {
        this.notice = '已取消保存';
        this.exportLabel = '导出图片';
        return;
      }
      this.creationCount += 1;
      this.lastExport = `${new Date().toLocaleString()} · ${getTemplateConfig(this.style).label}`;
      const work: WorkRecord = {
        id: `work_${Date.now()}_${Math.round(Math.random() * 10000)}`,
        createdAt: Date.now(),
        outputUri: result.targetUri,
        previewUri: result.previewUri,
        previewPath: result.previewPath,
        width: result.width,
        height: result.height,
        title: this.caption.length > 0 ? this.caption : getTemplateConfig(this.style).label,
        state: this.makeProjectState()
      };
      const updatedWorks: WorkRecord[] = [work];
      this.works.forEach((item: WorkRecord) => { updatedWorks.push(item); });
      this.works = await LibraryRepository.saveWorks(this.getAbilityContext(), updatedWorks);
      await this.saveSettings(false);
      this.notice = `已保存 ${result.width} × ${result.height}${result.wasLimited ? ' · 大图已安全缩放' : ''}`;
      this.exportLabel = '再次导出';
    } catch (err) {
      this.notice = '导出失败，请检查存储空间后重试';
      this.exportLabel = '重新导出';
    } finally {
      this.isExporting = false;
    }
  }

  private templateConfig(): TemplateConfig {
    return getTemplateConfig(this.style);
  }

  @Builder
  Header(title: string, back: boolean = false) {
    Row() {
      if (back) {
        Button('‹')
          .width(40).height(40).fontSize(30).fontColor('#FFFFFF')
          .backgroundColor('#1B1B1F').borderRadius(20)
          .onClick(() => {
            if (this.page === 'workDetail') {
              this.page = 'profile'; this.tab = 'profile';
            } else {
              this.page = 'home'; this.tab = 'home';
            }
          })
      }
      Column() {
        Text(title).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#F7F7FA')
        if (!back) {
          Text('把日常，印成一张有温度的相片纸').fontSize(12).fontColor('#8B8986').margin({ top: 3 })
        }
      }
      .alignItems(HorizontalAlign.Start).margin({ left: back ? 12 : 0 })
      Blank()
      if (!back) {
        Button('灵感').height(34).fontSize(11).fontWeight(FontWeight.Bold)
          .fontColor('#241A12').backgroundColor('#FFD98A').borderRadius(17)
      }
    }
    .width('100%')
  }

  @Builder
  Feature(icon: string, title: string, detail: string, color: string) {
    Column() {
      Row() {
        Text(icon).fontSize(21).width(42).height(42).textAlign(TextAlign.Center)
          .backgroundColor('#28FFFFFF').borderRadius(14)
        Blank()
        Text('↗').fontSize(18).fontColor('#DFFFFFFF')
      }
      Blank()
      Text(title).width('100%').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
      Text(detail).width('100%').fontSize(11).lineHeight(17).fontColor('#C9FFFFFF').margin({ top: 5 })
    }
    .width('48%').height(178).padding(18).alignItems(HorizontalAlign.Start)
    .backgroundColor(color).borderRadius(22)
    .onClick(() => {
      this.style = title.indexOf('票根') >= 0 ? 'theme' : title.indexOf('印章') >= 0 ? 'camera' : 'glass';
      this.page = 'gallery';
    })
  }

  @Builder
  BottomNav() {
    Row() {
      Column() {
        Text('▣').fontSize(20).fontColor(this.tab === 'home' ? '#FFCA74' : '#66666E')
        Text('开始创作').fontSize(10).fontColor(this.tab === 'home' ? '#FFCA74' : '#66666E')
      }.width('50%').onClick(() => { this.tab = 'home'; this.page = 'home'; })
      Column() {
        Text('♙').fontSize(20).fontColor(this.tab === 'profile' ? '#FFCA74' : '#66666E')
        Text('我的作品').fontSize(10).fontColor(this.tab === 'profile' ? '#FFCA74' : '#66666E')
      }.width('50%').onClick(() => { this.tab = 'profile'; this.page = 'profile'; })
    }
    .width(190).height(64).padding({ top: 8, bottom: 7 })
    .backgroundColor('#17171A').borderRadius(32)
  }

  @Builder
  Home() {
    Column() {
      this.Header('相片纸')
      Scroll() {
        Column({ space: 14 }) {
          Stack({ alignContent: Alignment.BottomStart }) {
            Image($r('app.media.lighthouse_demo')).width('100%').height(172)
              .objectFit(ImageFit.Cover).opacity(0.72)
            Column() {
              Row() {
                Text('PHOTO PAPER · 本周灵感').fontSize(9).fontWeight(FontWeight.Bold)
                  .fontColor('#FFE7B4').letterSpacing(1.0)
                Blank()
                Text('01').fontSize(9).fontColor('#241A12')
                  .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                  .backgroundColor('#FFD98A').borderRadius(8)
              }
              Text('今日相纸').fontSize(23).fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF').margin({ top: 58 })
              Text('给普通的一天，加一行只属于你的注脚')
                .fontSize(11).fontColor('#D9FFFFFF').margin({ top: 5 })
            }
            .width('100%').height('100%').padding(17).alignItems(HorizontalAlign.Start)
          }
          .width('100%').height(172).borderRadius(22).clip(true)
          .onClick(() => { this.style = 'glass'; this.page = 'gallery'; })
          Row() {
            this.Feature('□', '拍立得相纸', '留白边框、手写日期和一句心情', '#C96F49')
            this.Feature('⌁', '旅行纪念票根', '把城市、天气与里程装进票根', '#496EA8')
          }.width('100%').justifyContent(FlexAlign.SpaceBetween)
          Row() {
            this.Feature('✦', '日光印章', '用日期、时间与坐标盖住这一刻', '#A98945')
            Column() {
              Text('今日已装订').fontSize(12).fontColor('#928F8A')
              Text(`${this.creationCount}`).fontSize(32).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              Text('张相片纸').fontSize(11).fontColor('#66635F')
            }
            .width('48%').height(178).padding(18).alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Center).backgroundColor('#151518').borderRadius(22)
          }.width('100%').justifyContent(FlexAlign.SpaceBetween)
        }.width('100%').padding({ top: 18, bottom: 20 })
      }.layoutWeight(1).scrollBar(BarState.Off)
      this.BottomNav()
    }
    .width('100%').height('100%').padding({ left: 18, right: 18, top: 18, bottom: 12 })
    .constraintSize({ maxWidth: 680 })
    .backgroundColor('#050506')
  }

  @Builder
  PhotoTile(height: number) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image($r('app.media.lighthouse_demo')).width('100%').height(height).objectFit(ImageFit.Cover)
      Text('相片纸').fontSize(8).fontWeight(FontWeight.Bold).fontColor('#EFFFFFFF')
        .margin(10).padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .backgroundColor('#66000000').borderRadius(8)
    }
    .width('100%').height(height).borderRadius(12).clip(true)
    .onClick(() => {
      this.choosePhoto().catch(() => { this.notice = '相册暂时无法打开'; });
    })
  }

  @Builder
  Gallery() {
    Column() {
      this.Header('选择照片', true)
      Blank()
      Stack({ alignContent: Alignment.Bottom }) {
        Image($r('app.media.lighthouse_demo')).width('100%').height(300).objectFit(ImageFit.Cover).opacity(0.68)
        Column() {
          Text('从你的照片开始').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text('相片纸使用系统相册选择器，只读取你主动选择的照片')
            .fontSize(12).lineHeight(19).textAlign(TextAlign.Center).fontColor('#E0FFFFFF').margin({ top: 8 })
          Button('打开系统相册')
            .width(190).height(50).fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor('#241A12').backgroundColor('#FFD184').borderRadius(25).margin({ top: 20 })
            .onClick(() => { this.choosePhoto().catch(() => { this.notice = '相册暂时无法打开'; }); })
        }.width('100%').padding({ left: 24, right: 24, bottom: 30 })
      }.width('100%').height(300).borderRadius(28).clip(true)
      if (this.drafts.length > 0) {
        Button(`查看草稿箱 · ${this.drafts.length}`)
          .width('100%').height(48).fontSize(13).fontColor('#FFCA74')
          .backgroundColor('#1A1815').border({ width: 1, color: '#4B3D2C' }).borderRadius(24)
          .margin({ top: 14 })
          .onClick(() => { this.libraryTab = 'drafts'; this.tab = 'profile'; this.page = 'profile'; })
      }
      if (this.notice.length > 0) {
        Text(this.notice).width('100%').textAlign(TextAlign.Center)
          .fontSize(11).fontColor('#FFCA74').margin({ top: 12 })
      }
      Row() {
        Text('无需申请整个相册权限').fontSize(10).fontColor('#68686F')
        Text('·').fontSize(10).fontColor('#3F3F44').margin({ left: 8, right: 8 })
        Text('原图仅在本机处理').fontSize(10).fontColor('#68686F')
      }.margin({ top: 18 })
      Blank()
    }
    .width('100%').height('100%').padding({ left: 16, right: 16, top: 18 })
    .constraintSize({ maxWidth: 680 })
    .backgroundColor('#08080A')
  }

  @Builder
  Chip(label: string, value: string, group: string) {
    Text(label).fontSize(11).fontWeight(FontWeight.Medium)
      .fontColor((group === 'style' ? this.style : group === 'quality' ? this.quality : group === 'size' ? this.exportSize : this.ratio) === value ? '#241A12' : '#B6B6BE')
      .padding({ left: 13, right: 13, top: 9, bottom: 9 })
      .backgroundColor((group === 'style' ? this.style : group === 'quality' ? this.quality : group === 'size' ? this.exportSize : this.ratio) === value ? '#FFD184' : '#252529')
      .borderRadius(17)
      .onClick(() => {
        if (group === 'style' || group === 'ratio') {
          this.rememberEditorState();
        }
        if (group === 'style') {
          this.style = value;
        } else if (group === 'quality') {
          this.quality = value;
        } else if (group === 'size') {
          this.exportSize = value;
        } else {
          this.ratio = value;
        }
        this.saveSettings(false).catch(() => {});
      })
  }

  @Builder
  MarkContent(primaryColor: string, secondaryColor: string) {
    Row() {
      Column() {
        Text('相片纸 · PHOTO PAPER').fontSize(10).fontWeight(FontWeight.Bold).fontColor(primaryColor).letterSpacing(0.8)
        Text(this.style === 'theme' ? 'TRAVEL TICKET · NANJING' : this.showDevice ? `${this.caption} · ${this.deviceModel}` : this.caption)
          .fontSize(7).fontColor(secondaryColor).margin({ top: 3 })
      }.alignItems(HorizontalAlign.Start)
      Blank()
      if (this.showDate || this.showLocation) {
        Column() {
          if (this.showDate) {
            Text(this.shootingDate).fontSize(9).fontWeight(FontWeight.Bold).fontColor(primaryColor)
          }
          if (this.showLocation) {
            Text(this.locationText).fontSize(7).fontColor(secondaryColor).margin({ top: 3 })
          }
        }.alignItems(HorizontalAlign.End)
      }
    }
    .width('100%')
  }

  @Builder
  Mark() {
    if (this.style === 'camera') {
      Column() {
        this.MarkContent(this.templateConfig().primaryColor, this.templateConfig().secondaryColor)
      }
      .width('100%').padding(14).backgroundColor(this.templateConfig().backgroundColor).borderRadius(6)
      .border({ width: 1, color: this.templateConfig().borderColor })
    } else if (this.style === 'theme') {
      Column() {
        Row() {
          Text('TRAVEL NOTE').fontSize(8).fontWeight(FontWeight.Bold)
            .fontColor(this.templateConfig().primaryColor).letterSpacing(1.2)
          Blank()
          Text('NO. 0826').fontSize(8).fontColor(this.templateConfig().secondaryColor)
        }.width('100%')
        Divider().strokeWidth(1).color(this.templateConfig().borderColor).margin({ top: 8, bottom: 8 })
        this.MarkContent(this.templateConfig().primaryColor, this.templateConfig().secondaryColor)
      }
      .width('100%').padding(13).backgroundColor(this.templateConfig().backgroundColor).borderRadius(8)
      .border({ width: 1, color: this.templateConfig().borderColor, style: BorderStyle.Dashed })
    } else {
      Column() {
        this.MarkContent(this.templateConfig().primaryColor, this.templateConfig().secondaryColor)
      }
      .width('100%').padding(13)
      .backgroundColor(`#${Math.round(this.markOpacity * 2.55).toString(16)}0F1A23`).borderRadius(14)
      .border({ width: 1, color: this.templateConfig().borderColor })
    }
  }

  @Builder
  Editor() {
    Column() {
      this.Header('装订相片纸', true)
      Scroll() {
        Column({ space: 14 }) {
          Row() {
            Column() {
              Text(this.selectedUri.length > 0 ? '已选择真实照片' : '当前使用演示照片')
                .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              Text(this.selectedSize).fontSize(10).fontColor('#77777F').margin({ top: 4 })
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Button('更换照片').height(36).fontSize(11).fontColor('#241A12')
              .backgroundColor('#FFD184').borderRadius(18)
              .onClick(() => { this.choosePhoto().catch(() => {}); })
          }.width('100%')
          Row({ space: 8 }) {
            Button('↶ 撤销').height(34).fontSize(11).fontColor('#B7B7BE')
              .backgroundColor('#1C1C20').borderRadius(17).onClick(() => { this.undoEdit(); })
            Button('↷ 恢复').height(34).fontSize(11).fontColor('#B7B7BE')
              .backgroundColor('#1C1C20').borderRadius(17).onClick(() => { this.redoEdit(); })
            Blank()
            Text('所有处理均在本机完成').fontSize(9).fontColor('#626269')
          }.width('100%')
          Row() {
            Text('裁剪比例').fontSize(12).fontColor('#A8A8AF'); Blank()
            this.Chip('原图', 'original', 'ratio'); this.Chip('1:1', '1:1', 'ratio')
            this.Chip('4:5', '4:5', 'ratio'); this.Chip('3:4', '3:4', 'ratio'); this.Chip('9:16', '9:16', 'ratio')
          }.width('100%').padding(12).backgroundColor('#17171A').borderRadius(16)
          Row({ space: 8 }) {
            Button('调整照片')
              .height(34).fontSize(11)
              .fontColor(this.editTarget === 'photo' ? '#241A12' : '#B7B7BE')
              .backgroundColor(this.editTarget === 'photo' ? '#FFD184' : '#1C1C20').borderRadius(17)
              .onClick(() => { this.editTarget = 'photo'; })
            Button('调整水印')
              .height(34).fontSize(11)
              .fontColor(this.editTarget === 'mark' ? '#241A12' : '#B7B7BE')
              .backgroundColor(this.editTarget === 'mark' ? '#FFD184' : '#1C1C20').borderRadius(17)
              .onClick(() => { this.editTarget = 'mark'; })
            Blank()
            Button('恢复默认').height(34).fontSize(10).fontColor('#FFCA74')
              .backgroundColor('#231E18').borderRadius(17).onClick(() => { this.resetTransform(); })
          }.width('100%')
          Text(this.editTarget === 'photo' ? '单指拖动照片 · 双指缩放 1–3 倍' : '单指移动水印 · 双指调整水印大小')
            .width('100%').textAlign(TextAlign.Center).fontSize(10).fontColor('#77777F')
          Stack({ alignContent: Alignment.Center }) {
            Image(this.selectedUri.length > 0 ? this.selectedUri : $r('app.media.lighthouse_demo'))
              .width('100%').height('100%')
              .objectFit(ImageFit.Cover)
              .scale({ x: this.photoZoom, y: this.photoZoom })
              .translate({ x: this.photoOffsetX * this.previewWidth, y: this.photoOffsetY * this.previewHeight })
            Column() { this.Mark() }
              .width(`${Math.round(this.markScale * 94)}%`)
              .translate({
                x: this.markPositionX * this.previewWidth * (1 - this.markScale * 0.94) / 2,
                y: this.markPositionY * this.previewHeight * 0.42
              })
          }
          .id('exportCanvas')
          .width(this.ratio === '9:16' ? 230 : this.ratio === '4:5' || this.ratio === '3:4' ? 300 : this.ratio === '1:1' ? 330 : '100%')
          .height(this.ratio === '9:16' ? 409 : this.ratio === '4:5' ? 375 : this.ratio === '3:4' ? 400 : this.ratio === '1:1' ? 330 : 360)
          .borderRadius(22).clip(true)
          .onAreaChange((oldValue: Area, newValue: Area) => {
            this.previewWidth = Number(newValue.width);
            this.previewHeight = Number(newValue.height);
          })
          .priorityGesture(
            GestureGroup(GestureMode.Parallel,
              PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
                .onActionStart(() => { this.beginPan(); })
                .onActionUpdate((event: GestureEvent) => { this.updatePan(event); })
                .onActionEnd(() => { this.saveSettings(false).catch(() => {}); }),
              PinchGesture({ fingers: 2, distance: 3 })
                .onActionStart(() => { this.beginPinch(); })
                .onActionUpdate((event: GestureEvent) => { this.updatePinch(event); })
                .onActionEnd(() => { this.saveSettings(false).catch(() => {}); })
            )
          )
          Column() {
            Row() {
              Text('水印样式').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#F0F0F3'); Blank()
              Text(this.favoriteStyle === this.style ? '★ 已收藏' : '☆ 收藏模板')
                .fontSize(10).fontColor('#FFCA74')
                .onClick(() => {
                  this.favoriteStyle = this.style;
                  this.notice = '已收藏当前模板';
                  this.saveSettings(false).catch(() => {});
                })
            }.width('100%')
            Row({ space: 7 }) {
              ForEach(TEMPLATE_CONFIGS, (item: TemplateConfig) => {
                this.Chip(item.label, item.id, 'style')
              }, (item: TemplateConfig) => item.id)
            }.width('100%').margin({ top: 12 })
            Row() {
              Column() { Text('设备信息').fontSize(11).fontColor('#7D7D85'); Text(this.deviceModel).fontSize(13).fontColor('#FFFFFF').margin({ top: 5 }) }.alignItems(HorizontalAlign.Start)
              Blank()
              Column() { Text('镜头参数').fontSize(11).fontColor('#7D7D85'); Text('24mm  f/1.8').fontSize(13).fontColor('#FFFFFF').margin({ top: 5 }) }.alignItems(HorizontalAlign.End)
            }.width('100%').margin({ top: 16 })
            TextInput({ text: this.caption, placeholder: '写下一句照片注脚' })
              .width('100%').height(42).fontSize(12).fontColor('#FFFFFF')
              .placeholderColor('#66666E').backgroundColor('#242428').borderRadius(12)
              .margin({ top: 14 })
              .onFocus(() => { this.rememberEditorState(); })
              .onChange((value: string) => { this.caption = value; })
            Row() {
              Text('显示设备').fontSize(11).fontColor('#B5B5BC')
              Toggle({ type: ToggleType.Switch, isOn: this.showDevice })
                .onChange((value: boolean) => {
                  this.rememberEditorState(); this.showDevice = value; this.saveSettings(false).catch(() => {});
                })
              Text('日期').fontSize(11).fontColor('#B5B5BC').margin({ left: 8 })
              Toggle({ type: ToggleType.Switch, isOn: this.showDate })
                .onChange((value: boolean) => {
                  this.rememberEditorState(); this.showDate = value; this.saveSettings(false).catch(() => {});
                })
              Text('地点').fontSize(11).fontColor('#B5B5BC').margin({ left: 8 })
              Toggle({ type: ToggleType.Switch, isOn: this.showLocation })
                .onChange((value: boolean) => {
                  this.rememberEditorState(); this.showLocation = value; this.saveSettings(false).catch(() => {});
                })
            }.width('100%').margin({ top: 12 })
            Row() {
              Text('水印大小').fontSize(11).fontColor('#7D7D85')
              Slider({ value: this.markScale * 100, min: 62, max: 100, step: 2 })
                .layoutWeight(1).margin({ left: 10 })
                .selectedColor('#FFD184').trackColor('#303035')
                .onChange((value: number, mode: SliderChangeMode) => {
                  if (mode === SliderChangeMode.Begin) {
                    this.rememberEditorState();
                  }
                  this.markScale = value / 100;
                  if (mode === SliderChangeMode.End) {
                    this.saveSettings(false).catch(() => {});
                  }
                })
              Text(`${Math.round(this.markScale * 100)}%`).fontSize(10).fontColor('#FFCA74')
            }.width('100%').margin({ top: 10 })
            Row() {
              Text('水印透明度').fontSize(11).fontColor('#7D7D85')
              Slider({ value: this.markOpacity, min: 30, max: 100, step: 5 })
                .layoutWeight(1).margin({ left: 10 })
                .selectedColor('#FFD184').trackColor('#303035')
                .onChange((value: number, mode: SliderChangeMode) => {
                  if (mode === SliderChangeMode.Begin) {
                    this.rememberEditorState();
                  }
                  this.markOpacity = value;
                  if (mode === SliderChangeMode.End) {
                    this.saveSettings(false).catch(() => {});
                  }
                })
              Text(`${Math.round(this.markOpacity)}%`).fontSize(10).fontColor('#FFCA74')
            }.width('100%').margin({ top: 10 })
            Row() {
              Text('导出画质').fontSize(11).fontColor('#7D7D85'); Blank()
              this.Chip('标准', 'standard', 'quality')
              this.Chip('高清', 'high', 'quality')
            }.width('100%').margin({ top: 10 })
            Row() {
              Text('输出尺寸').fontSize(11).fontColor('#7D7D85'); Blank()
              this.Chip('原尺寸', '100', 'size')
              this.Chip('75%', '75', 'size')
              this.Chip('50%', '50', 'size')
            }.width('100%').margin({ top: 10 })
          }
          .width('100%').padding(16).alignItems(HorizontalAlign.Start)
          .backgroundColor('#17171A').borderRadius(18)
        }.width('100%').padding({ top: 16, bottom: 16 })
      }.layoutWeight(1).scrollBar(BarState.Off)
      Row({ space: 10 }) {
        if (this.activeDraftId.length > 0) {
          Button('另存').layoutWeight(1).height(52).fontColor('#9EBFFF')
            .backgroundColor('#151E2C').borderRadius(26)
            .onClick(() => { this.saveDraftAsNew().catch(() => { this.notice = '草稿保存失败'; }); })
        }
        Button(this.activeDraftId.length > 0 ? '更新草稿' : '保存草稿').layoutWeight(1).height(52).fontColor('#6EB0FF')
          .backgroundColor('#101B2A').border({ width: 1, color: '#315A84' }).borderRadius(26)
          .onClick(() => { this.saveDraft().catch(() => { this.notice = '草稿保存失败'; }); })
        Button(this.exportLabel).layoutWeight(2).height(52).fontWeight(FontWeight.Bold)
          .fontColor('#241A12').backgroundColor('#FFD184').borderRadius(26)
          .enabled(!this.isExporting)
          .onClick(() => { this.exportPhoto().catch(() => { this.notice = '导出失败'; }); })
      }.width('100%')
      if (this.notice.length > 0) {
        Text(this.notice).width('100%').textAlign(TextAlign.Center)
          .fontSize(11).fontColor('#FFCA74').margin({ top: 8 })
      }
    }
    .width('100%').height('100%').padding({ left: 16, right: 16, top: 18, bottom: 12 })
    .constraintSize({ maxWidth: 680 })
    .backgroundColor('#08080A')
  }

  @Builder
  EmptyLibrary(title: string, detail: string, action: string) {
    Column() {
      Text('相').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#241A12')
        .width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#FFD184').borderRadius(29)
      Text(title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ top: 16 })
      Text(detail).fontSize(11).lineHeight(18).textAlign(TextAlign.Center).fontColor('#77777F').margin({ top: 7 })
      Button(action).height(42).fontSize(12).fontColor('#241A12').backgroundColor('#FFD184')
        .borderRadius(21).margin({ top: 18 }).onClick(() => {
          if (this.page === 'workDetail') {
            this.tab = 'profile'; this.page = 'profile';
          } else {
            this.tab = 'home'; this.page = 'gallery';
          }
        })
    }.width('100%').padding({ top: 34, bottom: 34, left: 24, right: 24 })
    .backgroundColor('#151518').borderRadius(22)
  }

  @Builder
  WorkCard(work: WorkRecord) {
    Row({ space: 14 }) {
      Image(work.previewUri !== undefined && work.previewUri.length > 0 ? work.previewUri : work.outputUri)
        .width(104).height(104).objectFit(ImageFit.Cover).borderRadius(14)
      Column() {
        Text(work.title).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        Text(`${getTemplateConfig(work.state.style).label} · ${work.width} × ${work.height}`)
          .fontSize(10).fontColor('#FFCA74').margin({ top: 7 })
        Text(new Date(work.createdAt).toLocaleString()).fontSize(9).fontColor('#68686F').margin({ top: 5 })
        Row({ space: 8 }) {
          Button('查看').height(30).fontSize(10).fontColor('#241A12').backgroundColor('#FFD184').borderRadius(15)
            .onClick(() => { this.showWorkDetail(work); })
          Button('再编辑').height(30).fontSize(10).fontColor('#6EB0FF').backgroundColor('#132238').borderRadius(15)
            .onClick(() => { this.editWork(work).catch(() => {}); })
        }.margin({ top: 10 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(12).backgroundColor('#17171A').borderRadius(18)
  }

  @Builder
  DraftCard(draft: DraftRecord) {
    Row({ space: 13 }) {
      Image(draft.state.sourceUri).width(86).height(86).objectFit(ImageFit.Cover).borderRadius(13)
      Column() {
        Text(draft.title).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        Text(`${getTemplateConfig(draft.state.style).label} · ${draft.state.ratio}`)
          .fontSize(10).fontColor('#6EB0FF').margin({ top: 7 })
        Text(new Date(draft.updatedAt).toLocaleString()).fontSize(9).fontColor('#68686F').margin({ top: 5 })
        Row({ space: 8 }) {
          Button('继续编辑').height(30).fontSize(10).fontColor('#241A12').backgroundColor('#FFD184').borderRadius(15)
            .onClick(() => { this.openDraft(draft).catch(() => {}); })
          Button('删除').height(30).fontSize(10).fontColor('#E89090').backgroundColor('#2A1719').borderRadius(15)
            .onClick(() => { this.deleteDraft(draft.id).catch(() => {}); })
        }.margin({ top: 9 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(12).backgroundColor('#17171A').borderRadius(18)
  }

  @Builder
  Profile() {
    Column() {
      this.Header('我的作品')
      Row() {
        Button(`作品 ${this.works.length}`).layoutWeight(1).height(40).fontSize(12)
          .fontColor(this.libraryTab === 'works' ? '#241A12' : '#909098')
          .backgroundColor(this.libraryTab === 'works' ? '#FFD184' : '#1B1B1F').borderRadius(20)
          .onClick(() => { this.libraryTab = 'works'; })
        Button(`草稿 ${this.drafts.length}`).layoutWeight(1).height(40).fontSize(12)
          .fontColor(this.libraryTab === 'drafts' ? '#241A12' : '#909098')
          .backgroundColor(this.libraryTab === 'drafts' ? '#FFD184' : '#1B1B1F').borderRadius(20)
          .margin({ left: 8 }).onClick(() => { this.libraryTab = 'drafts'; })
      }.width('100%').margin({ top: 18 })
      Scroll() {
        Column({ space: 12 }) {
          if (this.libraryTab === 'works') {
            if (this.works.length === 0) {
              this.EmptyLibrary('还没有作品', '完成第一次导出后，作品会自动出现在这里。', '开始制作')
            } else {
              ForEach(this.works, (work: WorkRecord) => { this.WorkCard(work) }, (work: WorkRecord) => work.id)
            }
          } else {
            if (this.drafts.length === 0) {
              this.EmptyLibrary('草稿箱是空的', '编辑照片时点击“保存草稿”，可以保存多份创作。', '选择照片')
            } else {
              ForEach(this.drafts, (draft: DraftRecord) => { this.DraftCard(draft) },
                (draft: DraftRecord) => draft.id)
            }
          }
          Column() {
            Row() {
              Text('本地数据').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              Blank(); Text('不会上传').fontSize(10).fontColor('#7ECF9A')
            }.width('100%')
            Text(`作品记录最多 100 条 · 草稿最多 30 份 · ${this.quality === 'high' ? '高清' : '标准'}导出`)
              .width('100%').fontSize(10).fontColor('#68686F').margin({ top: 8 })
          }.width('100%').padding(15).alignItems(HorizontalAlign.Start).backgroundColor('#111113').borderRadius(16)
        }.width('100%').padding({ top: 14, bottom: 18 })
      }.layoutWeight(1).scrollBar(BarState.Off)
      if (this.notice.length > 0) {
        Text(this.notice).width('100%').textAlign(TextAlign.Center).fontSize(10).fontColor('#FFCA74')
          .margin({ bottom: 8 })
      }
      this.BottomNav()
    }
    .width('100%').height('100%').padding({ left: 18, right: 18, top: 18, bottom: 12 })
    .constraintSize({ maxWidth: 680 }).backgroundColor('#050506')
  }

  @Builder
  WorkDetail() {
    Column() {
      this.Header('作品详情', true)
      if (this.findSelectedWork() === undefined) {
        this.EmptyLibrary('作品记录不存在', '它可能已经被移除。', '返回首页')
      } else {
        Scroll() {
          Column() {
            Image(this.selectedWorkUri()).width('100%').height(470).objectFit(ImageFit.Contain)
              .backgroundColor('#111113').borderRadius(22)
            Text(this.selectedWorkTitle()).width('100%').fontSize(18).fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF').margin({ top: 18 })
            Text(this.selectedWorkInfo()).width('100%').fontSize(10).fontColor('#77777F').margin({ top: 7 })
            Row({ space: 10 }) {
              Button('再次编辑').layoutWeight(1).height(48).fontSize(13).fontWeight(FontWeight.Bold)
                .fontColor('#241A12').backgroundColor('#FFD184').borderRadius(24)
                .onClick(() => { this.editSelectedWork().catch(() => {}); })
              Button('移除记录').layoutWeight(1).height(48).fontSize(13).fontColor('#E89090')
                .backgroundColor('#2A1719').borderRadius(24)
                .onClick(() => { this.deleteWork(this.selectedWorkId).catch(() => {}); })
            }.width('100%').margin({ top: 18 })
            Text('移除记录不会删除系统相册中的成片').fontSize(10).fontColor('#68686F').margin({ top: 10 })
          }.width('100%').padding({ top: 18, bottom: 20 }).alignItems(HorizontalAlign.Start)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').padding({ left: 16, right: 16, top: 18, bottom: 12 })
    .constraintSize({ maxWidth: 680 }).backgroundColor('#08080A')
  }

  build() {
    Row() {
      if (this.page === 'home') { this.Home() }
      else if (this.page === 'gallery') { this.Gallery() }
      else if (this.page === 'editor') { this.Editor() }
      else if (this.page === 'workDetail') { this.WorkDetail() }
      else { this.Profile() }
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor('#050506')
  }
}
