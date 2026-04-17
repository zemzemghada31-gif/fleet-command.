// =============================================================================
//  firestore-service.js  —  Fleet Command  —  Firebase v10 Modular SDK
// =============================================================================
//
//  Firestore Schema (all collections & relations):
//
//  users/{userId}
//    ├── email         : string
//    ├── displayName   : string
//    ├── role          : "admin" | "viewer"
//    └── createdAt     : timestamp
//
//  vehicles/{vehicleId}           ← vehicleId = plate (e.g. "BT-904-TX")
//    ├── model         : string
//    ├── plate         : string
//    ├── year          : string
//    ├── status        : "ACTIVE" | "MAINTENANCE" | "IDLE"
//    ├── tracker       : deviceId ref  (e.g. "X-9941-ALPHA") | "Not Assigned"
//    ├── notes         : string
//    └── createdAt     : timestamp
//
//  devices/{deviceId}             ← deviceId = device code (e.g. "X-9941-ALPHA")
//    ├── model         : string
//    ├── assignment    : "ASSIGNED" | "UNASSIGNED" | "MAINTENANCE"
//    ├── lastConnection: string
//    ├── statusColor   : string  (hex, e.g. "0xFF3B82F6")
//    ├── vehicleId     : string ref → vehicles/{vehicleId} | null
//    └── createdAt     : timestamp
//
//  maintenanceTasks/{taskId}
//    ├── vehicleId     : string ref → vehicles/{vehicleId}
//    ├── vehiclePlate  : string  (denormalized for display)
//    ├── type          : string  (e.g. "Oil Change")
//    ├── status        : "PENDING" | "IN PROGRESS" | "COMPLETED" | "OVERDUE"
//    ├── dueDate       : string
//    ├── technician    : string
//    └── createdAt     : timestamp
//
//  maintenanceLogs/{logId}
//    ├── vehicleId     : string ref → vehicles/{vehicleId}
//    ├── title         : string
//    ├── type          : string
//    ├── notes         : string
//    ├── date          : string
//    ├── fileName      : string
//    ├── fileUrl       : string
//    └── createdAt     : timestamp  (serverTimestamp)
//
//  dtcCodes/{dtcId}
//    ├── vehicleId     : string ref → vehicles/{vehicleId}
//    ├── code          : string  (e.g. "P0301")
//    ├── description   : string
//    ├── severity      : "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"
//    ├── isActive      : boolean
//    └── detectedAt    : timestamp
//
//  alerts/{alertId}
//    ├── vehicleId     : string ref → vehicles/{vehicleId}
//    ├── type          : string
//    ├── message       : string
//    ├── severity      : "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"
//    ├── isScheduled   : boolean
//    ├── mechanic      : string
//    ├── scheduledDate : string
//    └── createdAt     : timestamp
//
//  analyticsStats/{period}_{horizon}_{region}  ← Analytics page (stats cards)
//    ├── period          : string  (last_30_days | quarterly | yearly)
//    ├── horizon         : string  (historical | realtime | predictive)
//    ├── region          : string  (all | north_america | europe | apac | latam)
//    ├── totalDistance   : string
//    ├── avgFuelEconomy  : string
//    ├── activeAlerts    : number
//    ├── distanceTrend   : string
//    └── fuelTrend       : string
//
//  analyticsTrends/{period}_{region}           ← Analytics page (chart)
//    ├── period          : string
//    ├── region          : string
//    ├── active          : array<number>
//    ├── maintenance     : array<number>
//    └── days            : array<string>
//
//  users/{userId}
//    ├── email         : string
//    ├── displayName   : string
//    ├── role          : "admin" | "viewer"
//    └── createdAt     : timestamp
//
//  vehicles/{vehicleId}           ← vehicleId = plate (e.g. "BT-904-TX")
//    ├── model         : string
//    ├── plate         : string
//    ├── year          : string
//    ├── status        : "ACTIVE" | "MAINTENANCE" | "IDLE"
//    ├── tracker       : deviceId ref  (e.g. "X-9941-ALPHA") | "Not Assigned"
//    ├── notes         : string
//    └── createdAt     : timestamp
//
//  devices/{deviceId}             ← deviceId = device code (e.g. "X-9941-ALPHA")
//    ├── model         : string
//    ├── assignment    : "ASSIGNED" | "UNASSIGNED" | "MAINTENANCE"
//    ├── lastConnection: string
//    ├── statusColor   : string  (hex, e.g. "0xFF3B82F6")
//    ├── vehicleId     : string ref → vehicles/{vehicleId} | null
//    └── createdAt     : timestamp
//
//  maintenanceTasks/{taskId}
//    ├── vehicleId     : string ref → vehicles/{vehicleId}
//    ├── vehiclePlate  : string
//    ├── type          : string
//    ├── status        : "PENDING" | "IN PROGRESS" | "COMPLETED" | "OVERDUE"
//    ├── dueDate       : string
//    ├── technician    : string
//    └── createdAt     : timestamp
//
//  maintenanceLogs/{logId}
//    ├── vehicleId     : string ref → vehicles/{vehicleId}
//    ├── title         : string
//    ├── type          : string
//    ├── notes         : string
//    ├── date          : string
//    ├── fileName      : string
//    ├── fileUrl       : string
//    └── createdAt     : timestamp
//
//  dtcCodes/{dtcId}
//    ├── vehicleId     : string ref → vehicles/{vehicleId}
//    ├── code          : string
//    ├── description   : string
//    ├── severity      : "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"
//    ├── isActive      : boolean
//    └── detectedAt    : timestamp
//
//  alerts/{alertId}
//    ├── vehicleId     : string ref → vehicles/{vehicleId}
//    ├── type          : string
//    ├── message       : string
//    ├── severity      : "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"
//    ├── isScheduled   : boolean
//    ├── mechanic      : string
//    ├── scheduledDate : string
//    └── createdAt     : timestamp
//
//  trajectoryPoints/{vehicleId}/points/{pointId}
//    ├── lat           : number
//    ├── lng           : number
//    ├── speed         : number
//    └── recordedAt    : timestamp
//
// =============================================================================

import {
  doc,
  collection,
  collectionGroup,
  onSnapshot,
  getDoc,
  getDocs,
  addDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  serverTimestamp,
} from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";

import { db } from "./firebase-config.js";

// =============================================================================
//  ANALYTICS
// =============================================================================

/**
 * Fetches pre-computed analytics stats from Firestore.
 * Doc ID format: {period}_{horizon}_{region}
 * @returns {Promise<object|null>}
 */
export async function getAnalyticsStats(period, horizon, region) {
  const id = `${period}_${horizon}_${region}`;
  const snap = await getDoc(doc(db, "analyticsStats", id));
  return snap.exists() ? snap.data() : null;
}

/**
 * Fetches pre-computed analytics trend arrays from Firestore.
 * Doc ID format: {period}_{region}
 * @returns {Promise<object|null>}
 */
export async function getAnalyticsTrends(period, region) {
  const id = `${period}_${region}`;
  const snap = await getDoc(doc(db, "analyticsTrends", id));
  return snap.exists() ? snap.data() : null;
}

// =============================================================================
//  VEHICLES
// =============================================================================

/** Real-time listener on a single vehicle document. */
export function listenToVehicle(vehicleId, callback) {
  return onSnapshot(doc(db, "vehicles", vehicleId), (snap) => {
    callback(snap.exists() ? { id: snap.id, ...snap.data() } : null);
  });
}

/** Real-time listener on the entire vehicles collection. */
export function listenToAllVehicles(callback) {
  return onSnapshot(collection(db, "vehicles"), (snap) => {
    callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
}

/** Updates the status field of a vehicle. */
export async function updateVehicleStatus(vehicleId, status) {
  await updateDoc(doc(db, "vehicles", vehicleId), { status });
}

/** Adds or fully replaces a vehicle document (id = plate). */
export async function setVehicle(vehicleId, data) {
  await setDoc(doc(db, "vehicles", vehicleId), {
    ...data,
    createdAt: serverTimestamp(),
  });
}

/** Updates arbitrary fields on a vehicle. */
export async function updateVehicle(vehicleId, data) {
  await updateDoc(doc(db, "vehicles", vehicleId), data);
}

/** Deletes a vehicle document. */
export async function deleteVehicle(vehicleId) {
  await deleteDoc(doc(db, "vehicles", vehicleId));
}

// =============================================================================
//  DEVICES
// =============================================================================

/** Real-time listener on the entire devices collection. */
export function listenToAllDevices(callback) {
  return onSnapshot(collection(db, "devices"), (snap) => {
    callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
}

/** Adds or fully replaces a device document (id = device code). */
export async function setDevice(deviceId, data) {
  await setDoc(doc(db, "devices", deviceId), {
    ...data,
    createdAt: serverTimestamp(),
  });
}

/** Updates arbitrary fields on a device. */
export async function updateDevice(deviceId, data) {
  await updateDoc(doc(db, "devices", deviceId), data);
}

/** Deletes a device document. */
export async function deleteDevice(deviceId) {
  await deleteDoc(doc(db, "devices", deviceId));
}

/**
 * Assigns a device to a vehicle and keeps both documents in sync.
 * Sets device.vehicleId and vehicle.tracker simultaneously.
 */
export async function assignDeviceToVehicle(deviceId, vehicleId) {
  await Promise.all([
    updateDoc(doc(db, "devices", deviceId), {
      vehicleId,
      assignment: "ASSIGNED",
    }),
    updateDoc(doc(db, "vehicles", vehicleId), { tracker: deviceId }),
  ]);
}

/** Unassigns a device from its vehicle. */
export async function unassignDevice(deviceId, vehicleId) {
  await Promise.all([
    updateDoc(doc(db, "devices", deviceId), {
      vehicleId: null,
      assignment: "UNASSIGNED",
    }),
    updateDoc(doc(db, "vehicles", vehicleId), { tracker: "Not Assigned" }),
  ]);
}

// =============================================================================
//  MAINTENANCE TASKS
// =============================================================================

/** Real-time listener on all maintenance tasks, ordered by dueDate asc. */
export function listenToAllTasks(callback) {
  const q = query(collection(db, "maintenanceTasks"), orderBy("dueDate", "asc"));
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
}

/** Real-time listener on tasks for a specific vehicle. */
export function listenToVehicleTasks(vehicleId, callback) {
  const q = query(
    collection(db, "maintenanceTasks"),
    where("vehicleId", "==", vehicleId),
    orderBy("dueDate", "asc")
  );
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
}

/** Adds a new maintenance task. Returns the new document id. */
export async function addTask(data) {
  const ref = await addDoc(collection(db, "maintenanceTasks"), {
    ...data,
    createdAt: serverTimestamp(),
  });
  return ref.id;
}

/** Updates a maintenance task document. */
export async function updateTask(taskId, data) {
  await updateDoc(doc(db, "maintenanceTasks", taskId), data);
}

/** Deletes a maintenance task. */
export async function deleteTask(taskId) {
  await deleteDoc(doc(db, "maintenanceTasks", taskId));
}

// =============================================================================
//  MAINTENANCE LOGS
// =============================================================================

/** Real-time listener on maintenanceLogs for a vehicle, ordered by date desc. */
export function listenToLogs(vehicleId, callback) {
  const q = query(
    collection(db, "maintenanceLogs"),
    where("vehicleId", "==", vehicleId),
    orderBy("date", "desc")
  );
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
}

/** Adds a new maintenance log with serverTimestamp. Returns the new document id. */
export async function addLog(vehicleId, { title, type, notes, date, fileName, fileUrl }) {
  const ref = await addDoc(collection(db, "maintenanceLogs"), {
    vehicleId,
    title,
    type,
    notes,
    date,
    fileName: fileName ?? "",
    fileUrl: fileUrl ?? "",
    createdAt: serverTimestamp(),
  });
  return ref.id;
}

/** Deletes a maintenanceLogs document by id. */
export async function deleteLog(logId) {
  await deleteDoc(doc(db, "maintenanceLogs", logId));
}

/** Updates a maintenanceLogs document. */
export async function updateLog(logId, data) {
  await updateDoc(doc(db, "maintenanceLogs", logId), data);
}

// =============================================================================
//  DTC CODES
// =============================================================================

/** Real-time listener on active DTC codes for a vehicle, ordered by detectedAt desc. */
export function listenToDTC(vehicleId, callback) {
  const q = query(
    collection(db, "dtcCodes"),
    where("vehicleId", "==", vehicleId),
    where("isActive", "==", true),
    orderBy("detectedAt", "desc")
  );
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
}

/** Marks a DTC code as resolved (isActive = false). */
export async function resolveDTC(dtcId) {
  await updateDoc(doc(db, "dtcCodes", dtcId), { isActive: false });
}

// =============================================================================
//  ALERTS
// =============================================================================

/** Real-time listener on alerts for a vehicle, ordered by createdAt desc. */
export function listenToAlerts(vehicleId, callback) {
  const q = query(
    collection(db, "alerts"),
    where("vehicleId", "==", vehicleId),
    orderBy("createdAt", "desc")
  );
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
}

/** Marks an alert as scheduled with mechanic and scheduledDate. */
export async function scheduleAlert(alertId, { mechanic, scheduledDate }) {
  await updateDoc(doc(db, "alerts", alertId), {
    isScheduled: true,
    mechanic,
    scheduledDate,
  });
}

/** Adds a new alert document. Returns the new document id. */
export async function addAlert(vehicleId, { type, message, severity }) {
  const ref = await addDoc(collection(db, "alerts"), {
    vehicleId,
    type,
    message,
    severity: severity ?? "MEDIUM",
    isScheduled: false,
    mechanic: "",
    scheduledDate: "",
    createdAt: serverTimestamp(),
  });
  return ref.id;
}

// =============================================================================
//  TRAJECTORY POINTS  (subcollection: trajectoryPoints/{vehicleId}/points)
// =============================================================================

/** Real-time listener on the last N trajectory points for a vehicle. */
export function listenToTrajectory(vehicleId, callback, maxPoints = 100) {
  const q = query(
    collection(db, "trajectoryPoints", vehicleId, "points"),
    orderBy("recordedAt", "desc"),
    limit(maxPoints)
  );
  return onSnapshot(q, (snap) => {
    // Return in ascending order so map can draw the polyline correctly
    const points = snap.docs.map((d) => ({ id: d.id, ...d.data() })).reverse();
    callback(points);
  });
}

/** Records a new GPS point for a vehicle. */
export async function addTrajectoryPoint(vehicleId, { lat, lng, speed }) {
  await addDoc(collection(db, "trajectoryPoints", vehicleId, "points"), {
    lat,
    lng,
    speed: speed ?? 0,
    recordedAt: serverTimestamp(),
  });
}

// =============================================================================
//  USERS
// =============================================================================

/** Fetches a single user profile document. */
export async function getUser(userId) {
  const snap = await getDoc(doc(db, "users", userId));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}

/** Creates or updates a user profile document. */
export async function setUser(userId, { email, displayName, role }) {
  await setDoc(
    doc(db, "users", userId),
    { email, displayName, role: role ?? "viewer", createdAt: serverTimestamp() },
    { merge: true }
  );
}
