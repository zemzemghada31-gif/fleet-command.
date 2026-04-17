import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-auth.js";
import { getStorage } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-storage.js";

const firebaseConfig = {
  apiKey:            "AIzaSyAceT8wKpyIL35XzehFkiaH9I9RMDfZ9FM",
  authDomain:        "fleet-command-b7128.firebaseapp.com",
  projectId:         "fleet-command-b7128",
  storageBucket:     "fleet-command-b7128.appspot.com",
  messagingSenderId: "623142089854",
  appId:             "1:623142089854:web:8ecd2fe7484985ee0f942f"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
export const storage = getStorage(app);
