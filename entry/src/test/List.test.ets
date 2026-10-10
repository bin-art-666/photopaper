import imageLayoutTest from './ImageLayout.test';
import templateCatalogTest from './TemplateCatalog.test';
import libraryRepositoryTest from './LibraryRepository.test';

export default function testsuite() {
  imageLayoutTest();
  templateCatalogTest();
  libraryRepositoryTest();
}
