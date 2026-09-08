import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import "./styles.css";

window.addEventListener("error", (event) => {
  document.body.innerHTML = `
    <div style="padding:30px;font-family:Arial;color:#b91c1c">
      <h2>App Error</h2>
      <pre style="white-space:pre-wrap">${event.error?.stack || event.message}</pre>
    </div>
  `;
});

window.addEventListener("unhandledrejection", (event) => {
  document.body.innerHTML = `
    <div style="padding:30px;font-family:Arial;color:#b91c1c">
      <h2>App Error</h2>
      <pre style="white-space:pre-wrap">${event.reason?.stack || event.reason}</pre>
    </div>
  `;
});

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
