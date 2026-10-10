import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { DraftRecord, WorkRecord } from '../models/LibraryModels';

const LIBRARY_NAME: string = 'photopaper_library';
const WORKS_KEY: string = 'works_v1';
const DRAFTS_KEY: string = 'drafts_v1';
const MAX_WORKS: number = 100;
const MAX_DRAFTS: number = 30;

export function sortWorksNewestFirst(records: WorkRecord[]): WorkRecord[] {
  return records.slice().sort((left: WorkRecord, right: WorkRecord) => right.createdAt - left.createdAt);
}

export function sortDraftsNewestFirst(records: DraftRecord[]): DraftRecord[] {
  return records.slice().sort((left: DraftRecord, right: DraftRecord) => right.updatedAt - left.updatedAt);
}

export function upsertDraft(records: DraftRecord[], draft: DraftRecord): DraftRecord[] {
  const result: DraftRecord[] = [];
  result.push(draft);
  for (let index = 0; index < records.length && result.length < MAX_DRAFTS; index++) {
    if (records[index].id !== draft.id) {
      result.push(records[index]);
    }
  }
  return sortDraftsNewestFirst(result);
}

export class LibraryRepository {
  private static async readString(context: common.UIAbilityContext, key: string): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, LIBRARY_NAME);
      return await store.get(key, '[]') as string;
    } catch (err) {
      throw new Error('本地作品数据读取失败');
    }
  }

  private static async writeString(context: common.UIAbilityContext, key: string, value: string): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, LIBRARY_NAME);
      await store.put(key, value);
      await store.flush();
    } catch (err) {
      throw new Error('本地作品数据保存失败');
    }
  }

  static async loadWorks(context: common.UIAbilityContext): Promise<WorkRecord[]> {
    try {
      const raw = await LibraryRepository.readString(context, WORKS_KEY);
      return sortWorksNewestFirst(JSON.parse(raw) as WorkRecord[]);
    } catch (err) {
      return [];
    }
  }

  static async saveWorks(context: common.UIAbilityContext, records: WorkRecord[]): Promise<WorkRecord[]> {
    const sorted = sortWorksNewestFirst(records).slice(0, MAX_WORKS);
    await LibraryRepository.writeString(context, WORKS_KEY, JSON.stringify(sorted));
    return sorted;
  }

  static async loadDrafts(context: common.UIAbilityContext): Promise<DraftRecord[]> {
    try {
      const raw = await LibraryRepository.readString(context, DRAFTS_KEY);
      return sortDraftsNewestFirst(JSON.parse(raw) as DraftRecord[]);
    } catch (err) {
      return [];
    }
  }

  static async saveDrafts(context: common.UIAbilityContext, records: DraftRecord[]): Promise<DraftRecord[]> {
    const sorted = sortDraftsNewestFirst(records).slice(0, MAX_DRAFTS);
    await LibraryRepository.writeString(context, DRAFTS_KEY, JSON.stringify(sorted));
    return sorted;
  }
}
