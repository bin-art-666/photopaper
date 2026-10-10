export interface ProjectState {
  sourceUri: string;
  selectedSize: string;
  deviceModel: string;
  shootingDate: string;
  locationText: string;
  style: string;
  ratio: string;
  quality: string;
  exportSize: string;
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

export interface DraftRecord {
  id: string;
  updatedAt: number;
  title: string;
  state: ProjectState;
}

export interface WorkRecord {
  id: string;
  createdAt: number;
  outputUri: string;
  previewUri?: string;
  previewPath?: string;
  width: number;
  height: number;
  title: string;
  state: ProjectState;
}
