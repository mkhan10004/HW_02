import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails, assertSucceeds, initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, runTransaction,
  serverTimestamp, setDoc, updateDoc,
} from 'firebase/firestore';

let env;
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Run through firebase emulators:exec.');
  }
  env = await initializeTestEnvironment({
    projectId: 'demo-vault-hunt',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
beforeEach(async () => { await env.clearFirestore(); });
after(async () => { await env?.cleanup(); });

const aliceDb = () => env.authenticatedContext('alice').firestore();
const bobDb = () => env.authenticatedContext('bob').firestore();
const profile = (uid) => ({
  uid, firstName: 'Alice', lastName: 'Example', role: 'member',
  registrationDateTime: serverTimestamp(),
});
const message = (authorUid = 'alice') => ({
  text: 'Hello board', authorUid, authorName: 'Alice Example',
  createdAt: serverTimestamp(), editedAt: null,
});
const post = (db) => doc(db, 'messages', 'sample');
async function seedAlice(db) {
  await assertSucceeds(setDoc(doc(db, 'users', 'alice'), profile('alice')));
  await assertSucceeds(setDoc(post(db), message()));
}

test('signed-out collection read is denied', async () => {
  await seedAlice(aliceDb());
  await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(), 'messages')));
});

test('another user can read but cannot edit or delete the post', async () => {
  await seedAlice(aliceDb());
  const db = bobDb();
  await assertSucceeds(getDoc(post(db)));
  await assertFails(updateDoc(post(db), { text: 'Changed', editedAt: serverTimestamp() }));
  await assertFails(deleteDoc(post(db)));
});

test('forged author UID and forged display name are denied', async () => {
  const db = aliceDb();
  await assertSucceeds(setDoc(doc(db, 'users', 'alice'), profile('alice')));
  await assertFails(setDoc(post(db), message('bob')));
  await assertFails(setDoc(post(db), { ...message(), authorName: 'Someone Else' }));
});

test('owner can create, read, edit and delete with immutable attribution', async () => {
  const db = aliceDb();
  await seedAlice(db);
  assert.equal((await assertSucceeds(getDoc(post(db)))).data().text, 'Hello board');
  await assertFails(updateDoc(post(db), { authorUid: 'bob', editedAt: serverTimestamp() }));
  await assertFails(updateDoc(post(db), { createdAt: serverTimestamp(), editedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(post(db), { text: 'Edited', editedAt: serverTimestamp() }));
  assert.equal((await getDoc(post(db))).data().text, 'Edited');
  await assertSucceeds(deleteDoc(post(db)));
  assert.equal((await getDoc(post(db))).exists(), false);
});

test('profiles are private, create-once and have a fixed descriptive role', async () => {
  const alice = aliceDb();
  const own = doc(alice, 'users', 'alice');
  await assertFails(setDoc(own, { ...profile('alice'), role: 'admin' }));
  await assertFails(setDoc(doc(alice, 'users', 'bob'), profile('bob')));
  await assertSucceeds(setDoc(own, profile('alice')));
  await assertSucceeds(getDoc(own));
  await assertFails(getDoc(doc(bobDb(), 'users', 'alice')));
  await assertFails(getDocs(collection(alice, 'users')));
  await assertFails(updateDoc(own, { firstName: 'Changed' }));
});

test('two transactions with the same operation ID produce one document', async () => {
  const db = aliceDb();
  await setDoc(doc(db, 'users', 'alice'), profile('alice'));
  const ref = doc(db, 'messages', 'same-operation');
  const send = () => runTransaction(db, async (tx) => {
    if (!(await tx.get(ref)).exists()) tx.set(ref, message());
  });
  await assertSucceeds(Promise.all([send(), send()]));
  const result = await getDocs(collection(db, 'messages'));
  assert.deepEqual(result.docs.map((item) => item.id), ['same-operation']);
});
