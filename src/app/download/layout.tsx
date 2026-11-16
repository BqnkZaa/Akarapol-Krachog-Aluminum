import { IBM_Plex_Sans_Thai } from "next/font/google";

const ibmPlexThai = IBM_Plex_Sans_Thai({
  weight: ["400", "500", "600"],
  subsets: ["thai", "latin"],
  display: "swap",
});

export default function DownloadLandingLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <div className={ibmPlexThai.className}>{children}</div>;
}
