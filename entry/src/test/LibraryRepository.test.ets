import { describe, it, expect } from '@ohos/hypium';
import { DraftRecord, ProjectState, WorkRecord } from '../main/ets/models/LibraryModels';
import { sortWorksNewestFirst, upsertDraft } from '../main/ets/services/LibraryRepository';

function projectState(uri: string): ProjectState {
  return {
    sourceUri: uri, selectedSize: '100 × 100', deviceModel: 'Device', shootingDate: '2026:08:26',
    locationText: 'Nanjing', style: 'glass', ratio: 'original', quality: 'high', exportSize: '100',
    caption: '记录', showDevice: true, showDate: true, showLocation: true, markOpacity: 72,
    photoZoom: 1, photoOffsetX: 0, photoOffsetY: 0,
    markPositionX: 0, markPositionY: 0.82, markScale: 0.92
  };
}

export default function libraryRepositoryTest() {
  describe('LibraryRepository', () => {
    it('sortsWorksNewestFirst', 0, () => {
      const oldWork: WorkRecord = {
        id: 'old', createdAt: 10, outputUri: 'old.jpg', width: 100, height: 100,
        title: '旧作品', state: projectState('old-source.jpg')
      };
      const newWork: WorkRecord = {
        id: 'new', createdAt: 20, outputUri: 'new.jpg', width: 100, height: 100,
        title: '新作品', state: projectState('new-source.jpg')
      };
      const sorted = sortWorksNewestFirst([oldWork, newWork]);
      expect(sorted[0].id).assertEqual('new');
      expect(sorted[1].id).assertEqual('old');
    });

    it('updatesDraftWithoutDuplicatingIt', 0, () => {
      const oldDraft: DraftRecord = {
        id: 'draft', updatedAt: 10, title: '旧标题', state: projectState('source.jpg')
      };
      const updatedDraft: DraftRecord = {
        id: 'draft', updatedAt: 30, title: '新标题', state: projectState('source.jpg')
      };
      const records = upsertDraft([oldDraft], updatedDraft);
      expect(records.length).assertEqual(1);
      expect(records[0].title).assertEqual('新标题');
      expect(records[0].updatedAt).assertEqual(30);
    });
  });
}
