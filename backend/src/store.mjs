import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

const defaultState = {
  parents: [],
  children: [],
  progress: [],
  attempts: [],
  subscriptions: [],
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
