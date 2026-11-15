import { MongoClient, type Collection } from "mongodb";
import type { ConsentEntry, TranscriptLine } from "../domain/callSession.js";
import type { Profile } from "../domain/profile.js";

export interface CallRecord {
  id: string;
  profileId: string;
  placeId: string;
  startedAt: number;
  endedAt: number;
  summary: string;
  transcript: TranscriptLine[];
  consents: ConsentEntry[];
}

export interface Store {
  profile(id: string): Promise<Profile | undefined>;
  saveProfile(profile: Profile): Promise<void>;
  saveCall(record: CallRecord): Promise<void>;
  calls(profileId: string, limit: number): Promise<CallRecord[]>;
}

export class MemoryStore implements Store {
  private readonly profiles = new Map<string, Profile>();
  private readonly history: CallRecord[] = [];

  constructor(seed: Profile[] = []) {
    for (const profile of seed) this.profiles.set(profile.id, profile);
  }

  async profile(id: string) {
    return this.profiles.get(id);
  }

  async saveProfile(profile: Profile) {
    this.profiles.set(profile.id, profile);
  }

  async saveCall(record: CallRecord) {
    this.history.unshift(record);
  }

  async calls(profileId: string, limit: number) {
    return this.history.filter((call) => call.profileId === profileId).slice(0, limit);
  }
}

type ProfileDoc = Profile & { _id: string };
type CallDoc = CallRecord & { _id: string };

export class MongoStore implements Store {
  private constructor(
    private readonly profiles: Collection<ProfileDoc>,
    private readonly history: Collection<CallDoc>,
  ) {}

  static async connect(uri: string, dbName: string, seed: Profile[]): Promise<MongoStore> {
    const client = await new MongoClient(uri).connect();
    const db = client.db(dbName);
    const store = new MongoStore(db.collection<ProfileDoc>("profiles"), db.collection<CallDoc>("calls"));
    await store.history.createIndex({ profileId: 1, startedAt: -1 });
    for (const profile of seed) {
      await store.profiles.updateOne({ _id: profile.id }, { $setOnInsert: { ...profile, _id: profile.id } }, { upsert: true });
    }
    return store;
  }

  async profile(id: string) {
    const doc = await this.profiles.findOne({ _id: id }, { projection: { _id: 0 } });
    return doc ?? undefined;
  }

  async saveProfile(profile: Profile) {
    await this.profiles.replaceOne({ _id: profile.id }, profile, { upsert: true });
  }

  async saveCall(record: CallRecord) {
    await this.history.insertOne({ ...record, _id: record.id });
  }

  async calls(profileId: string, limit: number) {
    return this.history.find({ profileId }, { projection: { _id: 0 } }).sort({ startedAt: -1 }).limit(limit).toArray();
  }
}
