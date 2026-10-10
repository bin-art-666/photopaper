import { describe, it, expect } from '@ohos/hypium';
import { calculateAdjustedCropLayout, calculateCropLayout, orientationToDegrees,
  ratioValue } from '../main/ets/utils/ImageLayout';

export default function imageLayoutTest() {
  describe('ImageLayout', () => {
    it('keepsOriginalRatio', 0, () => {
      const layout = calculateCropLayout(4000, 3000, 'original', 100);
      expect(layout.outputWidth).assertEqual(4000);
      expect(layout.outputHeight).assertEqual(3000);
      expect(layout.wasLimited).assertFalse();
    });

    it('centerCropsLandscapeToFourFive', 0, () => {
      const layout = calculateCropLayout(4000, 3000, '4:5', 100);
      expect(layout.sourceX).assertEqual(800);
      expect(layout.sourceY).assertEqual(0);
      expect(layout.outputWidth).assertEqual(2400);
      expect(layout.outputHeight).assertEqual(3000);
    });

    it('supportsHalfSizeExport', 0, () => {
      const layout = calculateCropLayout(4000, 3000, 'original', 50);
      expect(layout.outputWidth).assertEqual(2000);
      expect(layout.outputHeight).assertEqual(1500);
    });

    it('limitsVeryLargePhotos', 0, () => {
      const layout = calculateCropLayout(8000, 6000, 'original', 100);
      expect(layout.outputWidth).assertEqual(4096);
      expect(layout.outputHeight).assertEqual(3072);
      expect(layout.wasLimited).assertTrue();
    });

    it('zoomsAroundTheCenter', 0, () => {
      const layout = calculateAdjustedCropLayout(4000, 3000, 'original', 100, 2, 0, 0);
      expect(layout.sourceX).assertEqual(1000);
      expect(layout.sourceY).assertEqual(750);
      expect(layout.sourceWidth).assertEqual(2000);
      expect(layout.sourceHeight).assertEqual(1500);
      expect(layout.outputWidth).assertEqual(4000);
      expect(layout.outputHeight).assertEqual(3000);
    });

    it('clampsPanToPhotoBounds', 0, () => {
      const left = calculateAdjustedCropLayout(4000, 3000, 'original', 100, 2, 5, 0);
      const right = calculateAdjustedCropLayout(4000, 3000, 'original', 100, 2, -5, 0);
      expect(left.sourceX).assertEqual(0);
      expect(right.sourceX).assertEqual(2000);
    });

    it('mapsExifOrientation', 0, () => {
      expect(orientationToDegrees('6')).assertEqual(90);
      expect(orientationToDegrees('Bottom-right')).assertEqual(180);
      expect(orientationToDegrees('Left-bottom')).assertEqual(270);
      expect(orientationToDegrees('1')).assertEqual(0);
    });

    it('returnsExpectedRatios', 0, () => {
      expect(ratioValue('1:1', 4, 3)).assertEqual(1);
      expect(ratioValue('4:5', 4, 3)).assertEqual(0.8);
      expect(ratioValue('original', 4, 3)).assertEqual(4 / 3);
    });
  });
}
