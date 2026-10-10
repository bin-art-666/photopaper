import { describe, it, expect } from '@ohos/hypium';
import { getTemplateConfig, TEMPLATE_CONFIGS } from '../main/ets/models/TemplateCatalog';

export default function templateCatalogTest() {
  describe('TemplateCatalog', () => {
    it('containsThreeDistinctTemplates', 0, () => {
      expect(TEMPLATE_CONFIGS.length).assertEqual(3);
      expect(getTemplateConfig('glass').label).assertEqual('磨砂相纸');
      expect(getTemplateConfig('camera').label).assertEqual('拍立得相纸');
      expect(getTemplateConfig('theme').dashed).assertTrue();
    });

    it('fallsBackToGlassTemplate', 0, () => {
      expect(getTemplateConfig('missing').id).assertEqual('glass');
    });
  });
}
