export interface TemplateConfig {
  id: string;
  label: string;
  subtitle: string;
  primaryColor: string;
  secondaryColor: string;
  backgroundColor: string;
  borderColor: string;
  darkText: boolean;
  dashed: boolean;
  defaultScale: number;
}

export const TEMPLATE_CONFIGS: TemplateConfig[] = [
  {
    id: 'glass', label: '磨砂相纸', subtitle: '轻透玻璃与日常注脚',
    primaryColor: '#FFFFFF', secondaryColor: '#D4FFFFFF', backgroundColor: '#0F1A23',
    borderColor: '#55FFFFFF', darkText: false, dashed: false, defaultScale: 0.92
  },
  {
    id: 'camera', label: '拍立得相纸', subtitle: '暖白留边与手写感',
    primaryColor: '#17120E', secondaryColor: '#7A7068', backgroundColor: '#F4EFE6',
    borderColor: '#E3D8C7', darkText: true, dashed: false, defaultScale: 0.92
  },
  {
    id: 'theme', label: '旅行票根', subtitle: '城市、日期与坐标',
    primaryColor: '#302014', secondaryColor: '#705943', backgroundColor: '#E8C996',
    borderColor: '#8A6D50', darkText: true, dashed: true, defaultScale: 0.92
  }
];

export function getTemplateConfig(id: string): TemplateConfig {
  for (let index = 0; index < TEMPLATE_CONFIGS.length; index++) {
    if (TEMPLATE_CONFIGS[index].id === id) {
      return TEMPLATE_CONFIGS[index];
    }
  }
  return TEMPLATE_CONFIGS[0];
}
