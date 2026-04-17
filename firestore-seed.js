// =============================================================================
//  firestore-seed.js  —  Fleet Command
//  Run once in a browser console (with firebase-config.js loaded) to seed
//  Firestore with all mock data matching the Python backend.
//  Usage: import this file as a module in a temporary HTML page.
// =============================================================================

import {
  doc,
  collection,
  setDoc,
  addDoc,
  Timestamp,
} from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";

import { db } from "./firebase-config.js";

async function seed() {
  console.log("🌱 Seeding Firestore...");

  // ---------------------------------------------------------------------------
  // VEHICLES  (id = plate)
  // ---------------------------------------------------------------------------
  const vehicles = [
    { id: "BT-904-TX",  model: "Tesla Model X",     plate: "BT-904-TX",  year: "2022", status: "ACTIVE",       tracker: "X-9941-ALPHA", notes: "" },
    { id: "CA-123-VN",  model: "Mercedes Sprinter",  plate: "CA-123-VN",  year: "2021", status: "MAINTENANCE",  tracker: "Not Assigned", notes: "" },
    { id: "TX-4409-LP", model: "Ford Transit XL",    plate: "TX-4409-LP", year: "2023", status: "IDLE",         tracker: "X-9950-GAMMA", notes: "" },
  ];

  for (const v of vehicles) {
    const { id, ...data } = v;
    await setDoc(doc(db, "vehicles", id), { ...data, createdAt: Timestamp.now() });
    console.log(`  ✅ vehicle: ${id}`);
  }

  // ---------------------------------------------------------------------------
  // DEVICES  (id = device code)
  // ---------------------------------------------------------------------------
  const devices = [
    { id: "X-9941-ALPHA", model: "Apex Tracker V3", assignment: "ASSIGNED",    lastConnection: "2 mins ago",       statusColor: "0xFF3B82F6", vehicleId: "BT-904-TX"  },
    { id: "X-8820-BETA",  model: "Core Link Hub",   assignment: "UNASSIGNED",  lastConnection: "14 hrs ago",       statusColor: "0xFF64748B", vehicleId: null          },
    { id: "X-1011-DELTA", model: "Apex Tracker V3", assignment: "MAINTENANCE", lastConnection: "Offline (3 days)", statusColor: "0xFFF59E0B", vehicleId: null          },
    { id: "X-9950-GAMMA", model: "Core Link Hub",   assignment: "ASSIGNED",    lastConnection: "Just now",         statusColor: "0xFF3B82F6", vehicleId: "TX-4409-LP" },
  ];

  for (const d of devices) {
    const { id, ...data } = d;
    await setDoc(doc(db, "devices", id), { ...data, createdAt: Timestamp.now() });
    console.log(`  ✅ device: ${id}`);
  }

  // ---------------------------------------------------------------------------
  // MAINTENANCE TASKS
  // ---------------------------------------------------------------------------
  const tasks = [
    { vehicleId: "CA-123-VN",  vehiclePlate: "CA-123-VN",  type: "Oil Change",        status: "PENDING",     dueDate: "Oct 18, 2026", technician: "J. Torres"  },
    { vehicleId: "TX-4409-LP", vehiclePlate: "TX-4409-LP", type: "Tire Rotation",     status: "IN PROGRESS", dueDate: "Oct 15, 2026", technician: "A. Smith"   },
    { vehicleId: "BT-904-TX",  vehiclePlate: "BT-904-TX",  type: "Brake Inspection",  status: "COMPLETED",   dueDate: "Oct 10, 2026", technician: "M. Johnson" },
    { vehicleId: "CA-123-VN",  vehiclePlate: "CA-123-VN",  type: "Coolant Flush",     status: "PENDING",     dueDate: "Oct 20, 2026", technician: "J. Torres"  },
    { vehicleId: "TX-4409-LP", vehiclePlate: "TX-4409-LP", type: "Engine Diagnostic", status: "OVERDUE",     dueDate: "Oct 05, 2026", technician: "A. Smith"   },
  ];

  for (const t of tasks) {
    const ref = await addDoc(collection(db, "maintenanceTasks"), { ...t, createdAt: Timestamp.now() });
    console.log(`  ✅ maintenanceTask: ${ref.id} (${t.type})`);
  }

  // ---------------------------------------------------------------------------
  // DTC CODES
  // ---------------------------------------------------------------------------
  const dtcCodes = [
    { vehicleId: "BT-904-TX",  code: "P0301", description: "Cylinder 1 misfire detected",          severity: "HIGH",     isActive: true,  detectedAt: Timestamp.now() },
    { vehicleId: "BT-904-TX",  code: "P0420", description: "Catalyst system efficiency below threshold", severity: "MEDIUM", isActive: true,  detectedAt: Timestamp.now() },
    { vehicleId: "CA-123-VN",  code: "P0171", description: "System too lean (Bank 1)",              severity: "HIGH",     isActive: true,  detectedAt: Timestamp.now() },
    { vehicleId: "TX-4409-LP", code: "C0035", description: "Left front wheel speed sensor fault",   severity: "CRITICAL", isActive: true,  detectedAt: Timestamp.now() },
    { vehicleId: "TX-4409-LP", code: "P0128", description: "Coolant temperature below thermostat regulating temperature", severity: "LOW", isActive: false, detectedAt: Timestamp.now() },
  ];

  for (const dtc of dtcCodes) {
    const ref = await addDoc(collection(db, "dtcCodes"), dtc);
    console.log(`  ✅ dtcCode: ${ref.id} (${dtc.code})`);
  }

  // ---------------------------------------------------------------------------
  // ALERTS
  // ---------------------------------------------------------------------------
  const alerts = [
    { vehicleId: "BT-904-TX",  type: "SPEEDING",   message: "Speed exceeded 65 MPH on I-880",         severity: "HIGH",   isScheduled: false, mechanic: "", scheduledDate: "", createdAt: Timestamp.now() },
    { vehicleId: "BT-904-TX",  type: "LONG STOP",  message: "Unscheduled stop detected (45 min)",      severity: "MEDIUM", isScheduled: true,  mechanic: "A. Smith", scheduledDate: "Oct 18, 2026", createdAt: Timestamp.now() },
    { vehicleId: "CA-123-VN",  type: "MAINTENANCE",message: "Vehicle entered maintenance route",        severity: "LOW",    isScheduled: false, mechanic: "", scheduledDate: "", createdAt: Timestamp.now() },
    { vehicleId: "TX-4409-LP", type: "GEOFENCE",   message: "Vehicle left authorized zone",            severity: "HIGH",   isScheduled: false, mechanic: "", scheduledDate: "", createdAt: Timestamp.now() },
  ];

  for (const a of alerts) {
    const ref = await addDoc(collection(db, "alerts"), a);
    console.log(`  ✅ alert: ${ref.id} (${a.type})`);
  }

  // ---------------------------------------------------------------------------
  // TRAJECTORY POINTS  (subcollection per vehicle)
  // ---------------------------------------------------------------------------
  const trajectoryData = {
    "BT-904-TX": [
      { lat: 37.8044, lng: -122.2712 }, // Oakland
      { lat: 37.7749, lng: -122.4194 }, // San Francisco
      { lat: 37.5485, lng: -121.9886 }, // Fremont
      { lat: 37.3382, lng: -121.8863 }, // San Jose
    ],
    "CA-123-VN": [
      { lat: 37.3382, lng: -121.8863 }, // San Jose
      { lat: 37.4419, lng: -122.1430 }, // Palo Alto
    ],
    "TX-4409-LP": [
      { lat: 37.6213, lng: -122.3790 }, // SFO
      { lat: 37.7749, lng: -122.4194 }, // Downtown SF
      { lat: 37.8716, lng: -122.2727 }, // Berkeley
    ],
  };

  for (const [vehicleId, points] of Object.entries(trajectoryData)) {
    for (const p of points) {
      await addDoc(collection(db, "trajectoryPoints", vehicleId, "points"), {
        ...p,
        speed: Math.floor(Math.random() * 80) + 20,
        recordedAt: Timestamp.now(),
      });
    }
    console.log(`  ✅ trajectoryPoints: ${vehicleId} (${points.length} points)`);
  }

  // ---------------------------------------------------------------------------
  // USERS
  // ---------------------------------------------------------------------------
  await setDoc(doc(db, "users", "admin"), {
    email: "admin@fleet.io",
    displayName: "Admin User",
    role: "admin",
    createdAt: Timestamp.now(),
  });
  console.log("  ✅ user: admin");

  console.log("🎉 Seeding complete!");
}

seed().catch(console.error);
