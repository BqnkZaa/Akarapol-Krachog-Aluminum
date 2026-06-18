"use client";

import { useEffect } from "react";

export default function HashRowHighlighter() {
  useEffect(() => {
    const highlight = () => {
      const hash = window.location.hash.replace("#", "");
      if (!hash) return;

      const element = document.getElementById(hash);
      if (!element) return;

      // Apply styling
      if (element.tagName === "TR") {
        const tds = element.querySelectorAll("td");
        tds.forEach((td) => {
          td.classList.add("!bg-blue-50", "transition-colors", "duration-500");
        });
        if (tds[0]) {
          tds[0].classList.add("!border-l-4", "!border-blue-500");
        }

        // Clear after 5 seconds
        setTimeout(() => {
          tds.forEach((td) => {
            td.classList.remove("!bg-blue-50");
          });
          if (tds[0]) {
            tds[0].classList.remove("!border-l-4", "!border-blue-500");
          }
        }, 5000);
      } else {
        // For mobile card or other divs
        element.classList.add("!ring-2", "!ring-blue-500", "!bg-blue-50/50", "!shadow-md", "transition-all", "duration-500");
        setTimeout(() => {
          element.classList.remove("!ring-2", "!ring-blue-500", "!bg-blue-50/50", "!shadow-md");
        }, 5000);
      }
    };

    // Run on mount
    highlight();

    // Listen for hashchange (e.g. router pushes)
    window.addEventListener("hashchange", highlight);
    return () => {
      window.removeEventListener("hashchange", highlight);
    };
  }, []);

  return null;
}
