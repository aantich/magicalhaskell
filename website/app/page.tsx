"use client";

import { useState } from "react";

const publisher = "https://link.springer.com/book/10.1007/979-8-8688-1282-8";
const repository = "https://github.com/aantich/magicalhaskell";

function Arrow({ diagonal = false, className = "" }: { diagonal?: boolean; className?: string }) {
  return <svg className={className} width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{diagonal ? <path d="M6 18 18 6M6 6h12v12" /> : <path d="M4 12h15m-6-6 6 6-6 6" />}</svg>;
}

function Github({ size = 20 }: { size?: number }) {
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 .8a11.4 11.4 0 0 0-3.6 22.2c.6.1.8-.3.8-.6v-2.2c-3.2.7-3.9-1.3-3.9-1.3-.5-1.3-1.3-1.6-1.3-1.6-1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1 1.8 2.7 1.3 3.4 1 .1-.7.4-1.3.7-1.6-2.6-.3-5.3-1.3-5.3-5.7 0-1.3.5-2.3 1.2-3.1-.1-.3-.5-1.5.1-3.1 0 0 1-.3 3.2 1.2a11 11 0 0 1 5.8 0C17.2 5 18.2 5.3 18.2 5.3c.6 1.6.2 2.8.1 3.1.8.8 1.2 1.8 1.2 3.1 0 4.4-2.7 5.4-5.3 5.7.4.4.8 1.1.8 2.1v3.1c0 .3.2.7.8.6A11.4 11.4 0 0 0 12 .8Z" /></svg>;
}

function Spark({ className = "" }: { className?: string }) {
  return <svg className={className} width="40" height="40" viewBox="0 0 40 40" fill="none" aria-hidden="true"><path d="m20 1 3.4 15.6L39 20l-15.6 3.4L20 39l-3.4-15.6L1 20l15.6-3.4L20 1Z" stroke="currentColor" strokeWidth="1.2" /></svg>;
}

const journeys = [
  { number: "01", title: "Think in types.", range: "CHAPTERS 01—03", text: "Begin with an idea, a little imagination, and the building blocks of a new language.", chapters: ["Types & functions", "Building new types", "Type & category theory, gently introduced"] },
  { number: "02", title: "Find your composition.", range: "CHAPTERS 04—08", text: "Connect small pieces into expressive programs. Put the abstractions to work in a game of blackjack.", chapters: ["Typeclasses & monoids", "Functors & applicatives", "Composing with monads", "I/O & transformer stacks", "A complete blackjack program"] },
  { number: "03", title: "Make it intelligent.", range: "CHAPTERS 09—13", text: "Take functional ideas into AI: from your first chat agent to retrieval and multi-agent systems.", chapters: ["Getting started with AI", "A terminal chat agent", "An AI framework for the web", "Deeper into Haskell & retrieval", "Multi-agent systems & Arrows"] },
];

export default function Home() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [copyState, setCopyState] = useState<"idle" | "copied" | "error">("idle");

  async function copyCommand() {
    try {
      await navigator.clipboard.writeText("git clone https://github.com/aantich/magicalhaskell.git");
      setCopyState("copied");
      window.setTimeout(() => setCopyState("idle"), 2500);
    } catch {
      setCopyState("error");
    }
  }

  return (
    <>
      <a className="skip-link" href="#main">Skip to content</a>
      <header className="site-header">
        <div className="container header-inner">
          <a className="wordmark" href="#" aria-label="Magical Haskell home"><span className="lambda" aria-hidden="true">λ</span><span>magical haskell<span className="wordmark-dot">.</span></span></a>
          <button className="menu-toggle" aria-expanded={menuOpen} aria-controls="navigation" onClick={() => setMenuOpen(!menuOpen)}>{menuOpen ? "Close" : "Menu"}<span aria-hidden="true">{menuOpen ? "−" : "+"}</span></button>
          <nav id="navigation" className={menuOpen ? "navigation is-open" : "navigation"} aria-label="Main navigation">
            <a href="#the-book" onClick={() => setMenuOpen(false)}>The book</a>
            <a href="#inside" onClick={() => setMenuOpen(false)}>What’s inside</a>
            <a href="#author" onClick={() => setMenuOpen(false)}>The author</a>
            <a className="nav-github" href={repository} aria-label="Book source code on GitHub"><Github /></a>
            <a className="nav-cta" href="#get-the-book" onClick={() => setMenuOpen(false)}>Get the book <Arrow diagonal /></a>
          </nav>
        </div>
      </header>

      <main id="main">
        <section className="hero container" aria-labelledby="hero-title">
          <div className="hero-copy">
            <div className="eyebrow hero-eyebrow"><span className="status-dot" /> A LITTLE THEORY. A LOT OF POSSIBILITY.</div>
            <h1 id="hero-title">Magical<br /><em>Haskell.</em><Spark className="title-spark" /></h1>
            <p className="hero-subtitle">A new way to think.<br />A little magic to get you there.</p>
            <p className="hero-description">Discover the beauty of functional programming, from the first spark of type theory to building your own AI agents.</p>
            <div className="hero-actions">
              <a className="button button-dark" href="#get-the-book">Get the book <Arrow diagonal /></a>
              <a className="text-link" href="#inside">Take a look inside <span aria-hidden="true">↓</span></a>
            </div>
            <div className="hero-byline"><span className="short-rule" /> By <a href="#author">Anton Antich</a><span className="byline-divider">/</span> Published by <span className="apress-word">Apress</span></div>
          </div>
          <div className="hero-art">
            <div className="art-topline"><span>THE ART OF THINKING FUNCTIONALLY</span><span aria-hidden="true">↗</span></div>
            <div className="orbital orbital-one" /><div className="orbital orbital-two" /><div className="orbital orbital-three" />
            <span className="art-lambda" aria-hidden="true">λ</span>
            <span className="art-symbol symbol-a" aria-hidden="true">a → b</span>
            <Spark className="art-spark" />
            <div className="book-object">
              <div className="book-spine" aria-hidden="true"><span>Magical Haskell</span></div>
              <img className="book-cover" src="./images/magical-haskell-cover.jpg" alt="Magical Haskell by Anton Antich — the purple and gold Apress book cover" width="827" height="1254" fetchPriority="high" />
            </div>
            <div className="edition-stamp"><span>FROM</span><strong>types to AI</strong><span>ONE BEAUTIFUL JOURNEY</span></div>
            <div className="art-bottomline"><span>FOR THE BEAUTIFULLY CURIOUS.</span><span>01 / 13</span></div>
          </div>
        </section>

        <div className="book-facts container" aria-label="Book facts">
          <div><strong>13</strong><span>Chapters of discovery</span></div>
          <div><strong>74</strong><span>Illustrations along the way</span></div>
          <div><strong>2025</strong><span>First edition · Apress</span></div>
          <div><span className="formats-icon" aria-hidden="true">▤</span><span>Paperback & eBook</span></div>
        </div>

        <section id="the-book" className="about-section container section-space" aria-labelledby="about-title">
          <div className="section-kicker"><span className="eyebrow">A DIFFERENT KIND OF PROGRAMMING BOOK</span><span className="tiny-mark" aria-hidden="true">✳</span></div>
          <div className="about-grid">
            <h2 id="about-title">Big ideas.<br /><em>Gentle beginnings.</em></h2>
            <div className="about-copy"><p className="lead">There’s a beautiful language hiding behind the unfamiliar symbols.</p><p>Explore it through playful metaphors, visual explanations, and code you can make your own. Build an intuition for types, learn how programs fit together, and follow those ideas all the way to practical AI.</p><p className="about-note">For curious programmers, Haskell enthusiasts, and anyone who has ever wondered what all the monad fuss is about.</p><a className="underlined-link" href={publisher}>Read the publisher’s overview <Arrow diagonal /></a></div>
          </div>
          <div className="concept-trail" aria-label="The learning path"><span>Types</span><Arrow /><span>Functions</span><Arrow /><span>Composition</span><Arrow /><span>Possibilities<span className="small-star">✧</span></span></div>
        </section>

        <section id="inside" className="inside-section section-space" aria-labelledby="inside-title">
          <div className="container inside-grid">
            <div className="inside-intro"><span className="eyebrow">BETWEEN THE COVERS</span><h2 id="inside-title">Follow your<br /><em>curiosity.</em></h2><p>Thirteen chapters. A path from first principles to programs with a mind of their own.</p><a className="underlined-link" href={`${publisher}#toc`}>Full table of contents <Arrow diagonal /></a><div className="margin-note"><span aria-hidden="true">λ</span><p>Small functions.<br />Wonderful things.</p></div></div>
            <div className="chapter-groups">
              {journeys.map((journey, groupIndex) => <details className="chapter-group" key={journey.number} open={groupIndex === 0 ? true : undefined}>
                <summary><span className="chapter-number">{journey.number}</span><span className="chapter-heading"><span className="eyebrow">{journey.range}</span><span className="chapter-title">{journey.title}</span></span><span className="expand-icon" aria-hidden="true" /></summary>
                <div className="chapter-content"><p>{journey.text}</p><ol start={groupIndex === 0 ? 1 : groupIndex === 1 ? 4 : 9}>{journey.chapters.map((chapter) => <li key={chapter}>{chapter}</li>)}</ol></div>
              </details>)}
              <p className="contents-note">A gentle start. Plenty of room to go deep.</p>
            </div>
          </div>
        </section>

        <section id="code" className="code-section container section-space" aria-labelledby="code-title">
          <div className="code-panel"><div className="code-window-header"><span className="window-dots" aria-hidden="true"><i /><i /><i /></span><span>a little composition.hs</span><span>HASKELL</span></div><pre aria-label="A simple Haskell example that composes two functions"><code><span className="code-comment">-- Small pieces. New possibilities.</span>{"\n\n"}<span className="code-name">spark</span> <span className="code-purple">::</span> <span className="code-gold">String</span> <span className="code-purple">-&gt;</span> <span className="code-gold">String</span>{"\n"}<span className="code-name">spark</span> idea <span className="code-purple">=</span> idea <span className="code-purple">++</span> <span className="code-green">"!"</span>{"\n\n"}<span className="code-name">wonder</span> <span className="code-purple">::</span> <span className="code-gold">String</span> <span className="code-purple">-&gt;</span> <span className="code-gold">String</span>{"\n"}<span className="code-name">wonder</span> <span className="code-purple">=</span> spark <span className="code-purple">.</span> reverse{"\n\n"}<span className="code-comment">-- λ&gt; wonder "lleksaH"</span>{"\n"}<span className="code-green">-- "Haskell!"</span></code></pre><div className="code-window-footer"><span className="code-status" /> Illustrative example · try it in GHCi</div></div>
          <div className="code-copy"><span className="eyebrow">READ IT. RUN IT. MAKE IT YOURS.</span><h2 id="code-title">The magic is<br /><em>in the making.</em></h2><p>The book’s companion code is on GitHub. Explore the examples, experiment with an idea, and see where it takes you.</p><a className="button button-dark" href={repository}><Github /> Explore the source code <Arrow diagonal /></a><div className="clone-command"><code>git clone …/magicalhaskell.git</code><button onClick={copyCommand} aria-label="Copy the full Git clone command">{copyState === "copied" ? "Copied!" : "Copy"}</button></div><span className="copy-feedback" role="status">{copyState === "error" ? "Copy unavailable. Full command: git clone https://github.com/aantich/magicalhaskell.git" : copyState === "copied" ? "Clone command copied to clipboard." : ""}</span><a className="small-link" href="https://github.com/Apress/Magical-Haskell">Also available in the Apress repository <Arrow diagonal /></a></div>
        </section>

        <section id="author" className="author-section section-space" aria-labelledby="author-title">
          <div className="container author-grid"><div className="author-photo-wrap"><img src="./images/anton-antich.jpg" alt="Anton Antich, author of Magical Haskell" width="640" height="640" loading="lazy" /><span className="photo-caption">THE HUMAN BEHIND THE HASKELL</span><Spark className="portrait-spark" /></div><div className="author-copy"><span className="eyebrow">A NOTE ABOUT THE AUTHOR</span><h2 id="author-title">Hello, I’m<br /><em>Anton Antich.</em></h2><p className="lead">Entrepreneur by trade.<br />Curious about how things work, always.</p><p>With a background in physics and a fascination for AI, type theory, and functional programming, I wrote Magical Haskell to make these ideas more approachable—and share the pleasure of figuring them out.</p><div className="author-links"><a href="https://x.com/aantich">X / Twitter <Arrow diagonal /></a><a href="https://medium.com/@aantich">Medium <Arrow diagonal /></a><a href="https://www.linkedin.com/in/aantich/">LinkedIn <Arrow diagonal /></a><a href="https://github.com/aantich">GitHub <Arrow diagonal /></a></div></div></div>
        </section>

        <section id="get-the-book" className="get-section container section-space" aria-labelledby="get-title"><div className="get-decoration" aria-hidden="true">λ</div><span className="eyebrow">YOUR NEXT CHAPTER</span><h2 id="get-title">A little curiosity.<br /><em>Infinite possibilities.</em></h2><p>Let’s make something magical.</p><div className="purchase-links"><a className="button button-dark" href={publisher}>Get it from Apress <Arrow diagonal /></a><a className="button button-outline" href="https://www.amazon.com/dp/B0DQGF9SL7">Find it on Amazon <Arrow diagonal /></a></div><p className="purchase-note">Available in paperback, PDF & EPUB.</p></section>
      </main>

      <footer className="site-footer"><div className="container footer-top"><a className="wordmark" href="#"><span className="lambda" aria-hidden="true">λ</span><span>magical haskell<span className="wordmark-dot">.</span></span></a><span className="footer-tagline">Functional thinking. Human-friendly.</span><a className="back-top" href="#">Back to top <span aria-hidden="true">↑</span></a></div><div className="container footer-bottom"><span>© {new Date().getFullYear()} Anton Antich</span><a href={publisher}>Published by Apress · First edition, 2025</a><a href={repository}>Made for the curious <Github size={15} /></a></div></footer>
    </>
  );
}
