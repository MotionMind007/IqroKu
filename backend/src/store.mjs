import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

const defaultState = {
  parents: [],
  children: [],
  progress: [],
  attempts: [],
  subscriptions: [],
  dailyPrayers: [
    {
      id: 'doa-belajar',
      title: 'Doa Sebelum Belajar',
      category: 'Belajar',
      arabic: 'رَبِّ زِدْنِي عِلْمًا وَارْزُقْنِي فَهْمًا',
      latin: 'Rabbi zidnii ilman warzuqnii fahman',
      meaning: 'Ya Rabb, tambahkanlah ilmuku dan berilah aku pemahaman.',
      sortOrder: 10,
      active: true,
      createdAt: '2026-06-16T00:00:00.000Z',
      updatedAt: '2026-06-16T00:00:00.000Z',
    },
    {
      id: 'doa-orang-tua',
      title: 'Doa Kedua Orang Tua',
      category: 'Keluarga',
      arabic: 'رَبِّ اغْفِرْ لِي وَلِوَالِدَيَّ وَارْحَمْهُمَا',
      latin: 'Rabbighfir lii waliwaalidayya warhamhumaa',
      meaning:
        'Ya Rabb, ampunilah aku dan kedua orang tuaku, serta sayangilah mereka.',
      sortOrder: 20,
      active: true,
      createdAt: '2026-06-16T00:00:00.000Z',
      updatedAt: '2026-06-16T00:00:00.000Z',
    },
    {
      id: 'doa-sebelum-tidur',
      title: 'Doa Sebelum Tidur',
      category: 'Harian',
      arabic: 'بِاسْمِكَ اللَّهُمَّ أَحْيَا وَأَمُوتُ',
      latin: 'Bismikallaahumma ahyaa wa amuut',
      meaning: 'Dengan nama-Mu ya Allah aku hidup dan aku mati.',
      sortOrder: 30,
      active: true,
      createdAt: '2026-06-16T00:00:00.000Z',
      updatedAt: '2026-06-16T00:00:00.000Z',
    },
    {
      id: 'doa-bangun-tidur',
      title: 'Doa Bangun Tidur',
      category: 'Harian',
      arabic:
        'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
      latin:
        'Alhamdulillaahil ladzii ahyaanaa ba’da maa amaatanaa wa ilaihin nusyuur',
      meaning:
        'Segala puji bagi Allah yang menghidupkan kami setelah mematikan kami, dan kepada-Nya kami kembali.',
      sortOrder: 40,
      active: true,
      createdAt: '2026-06-16T00:00:00.000Z',
      updatedAt: '2026-06-16T00:00:00.000Z',
    },
  ],
};

export class JsonStore {
  constructor(path = process.env.IQROKU_BACKEND_STORE ?? 'data/dev-store.json') {
    this.path = resolve(path);
    this.state = null;
    this.writeQueue = Promise.resolve();
  }

  async load() {
    if (this.state) {
      return this.state;
    }

    try {
      const raw = await readFile(this.path, 'utf8');
      this.state = { ...defaultState, ...JSON.parse(raw) };
    } catch (error) {
      if (error.code !== 'ENOENT') {
        throw error;
      }
      this.state = structuredClone(defaultState);
      await this.save();
    }

    return this.state;
  }

  async save() {
    await mkdir(dirname(this.path), { recursive: true });
    const payload = JSON.stringify(this.state ?? defaultState, null, 2);
    this.writeQueue = this.writeQueue.then(() => writeFile(this.path, payload));
    await this.writeQueue;
  }
}
