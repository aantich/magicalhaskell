import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://magicalhaskell.com"),
  alternates: { canonical: "/" },
  title: "Magical Haskell — A Little Theory. A Lot of Possibility. | Anton Antich",
  description: "A friendly journey through functional programming, type theory, and artificial intelligence. Discover Magical Haskell by Anton Antich, published by Apress.",
  authors: [{ name: "Anton Antich", url: "https://github.com/aantich" }],
  openGraph: {
    title: "Magical Haskell by Anton Antich",
    description: "A friendly approach to modern functional programming, type theory, and artificial intelligence.",
    type: "website",
    url: "https://magicalhaskell.com/",
    images: [{ url: "https://media.springernature.com/full/springer-static/cover-hires/book/979-8-8688-1282-8", width: 827, height: 1254, alt: "Magical Haskell book cover" }],
  },
  twitter: { card: "summary", creator: "@aantich", title: "Magical Haskell by Anton Antich", images: ["https://media.springernature.com/full/springer-static/cover-hires/book/979-8-8688-1282-8"] },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "Book",
            name: "Magical Haskell",
            alternativeHeadline: "A Friendly Approach to Modern Functional Programming, Type Theory, and Artificial Intelligence",
            isbn: "9798868812811",
            bookEdition: "1",
            datePublished: "2025-04-17",
            inLanguage: "en",
            image: "https://media.springernature.com/full/springer-static/cover-hires/book/979-8-8688-1282-8",
            url: "https://link.springer.com/book/10.1007/979-8-8688-1282-8",
            author: {
              "@type": "Person", name: "Anton Antich",
              sameAs: ["https://x.com/aantich", "https://medium.com/@aantich", "https://www.linkedin.com/in/aantich/", "https://github.com/aantich"],
            },
            publisher: { "@type": "Organization", name: "Apress" },
          }) }}
        />
        {children}
      </body>
    </html>
  );
}
