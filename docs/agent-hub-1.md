markdown_content = """# How to Build a Team of AI Agents That Run Your Business While You Sleep — The Complete Playbook

**Original Thread:** [@sairahul1](https://x.com/sairahul1/status/2055199726589391151)  
*Note: The user referred to 7 agents, based on the article's quote: "replace the three roles every early-stage business needs first, and then add seven more that most founders don't even know exist." Below is the complete extraction of all agents discussed in the thread.*

---

## The Wall Every Solo Founder Hits

There is more work than one person can do. Revenue is coming in, but not enough to hire three people at $60,000 a year each. So you keep doing everything yourself: research, content, customer support, operations, email, bookkeeping. You become the bottleneck for your own business.

In 2026, the smartest solo founders are not hiring their first three employees. They are building them. Right now, today, using Claude, MCP servers, and agentic workflows — you can replace the three roles every early-stage business needs first, and then add more that most founders don't even know exist. 

### The Mental Shift You Need First
Most people build AI agents like chatbots. They open a session, ask a question, get an answer, close it. That is not an agent. That is expensive autocomplete.

**A real agent is a job description + a trigger + an output.**

Three rules that separate agents that survive from agents that die:
1. **Every agent has a job description, not a vibe.** "Pulls 10 trending posts from X every morning at 8am, drafts 3 replies in my voice, posts the highest-scoring one if I approve." That is a job description. "Help with content" is a vibe.
2. **You need to see what they are doing in real time.** Most agents fail silently.
3. **Hosting them on your laptop is not a strategy.** 90% of builders die here.

---

## The 3 Agents Every Business Needs First

Build these three before anything else. They cover the roles that eat the most founder time and cost the most to hire.

### 1. The Research Agent
* **Replaces:** Market intelligence analyst ($5,000–$8,000/month)
* **What it does:** Monitors competitors, tracks industry trends, identifies opportunities, and delivers a weekly brief every Monday morning.
* **How to build it:** Feed it your top 10 competitors, target market, and ideal customer profile. Give it tools like an MCP server connected to a web search API, Google Drive, and your email.
* **Outputs:** A concise 1-page executive summary with 3 key developments, recommended actions, and links to sources.

### 2. The Content Agent
* **Replaces:** Content writer + social media manager ($6,000–$12,000/month)
* **What it does:** Handles the full content lifecycle—ideation, research, drafting, editing, repurposing, and scheduling.
* **How to build it:** Feed it your top 20 best-performing posts, style guide, audience profile, and anti-examples. Connect it to your CMS or scheduling platform and web search.
* **Quality Gates:** After every draft, it scores the output on voice match, hook strength, and originality. Anything below your threshold is automatically rewritten. 

### 3. The Operations Agent
* **Replaces:** Executive assistant + chief of staff ($4,000–$7,000/month)
* **What it does:** Handles email triage, meeting prep, weekly reporting, and follow-up tracking.
* **Core workflows:** Categorizes emails, drafts routine responses, pulls relevant docs for meeting prep, and compiles weekly metrics.

> **Pro Tip: How to Make All Three Work Together**
> Individual agents are useful. Connected agents are a team. Build a shared knowledge base that all three agents can read and write to. 

---

## The 10 Additional Claude Code Agents

Once your business agents are running, add these to automate your development and operational workflow. *(Note: This section expands on the "7 more" mentioned in the intro).*

### 4. The PR Reviewer
* **Type:** Slash command + GitHub hook
* **What it does:** Reads the diff of any open PR, checks for bugs, missing tests, security issues, and style violations. Drops a comment within 90 seconds. 

### 5. The Test Generator
* **Type:** Slash command + pre-commit hook
* **What it does:** Watches for new functions without tests. Writes 3–5 cases per function (happy path, edge cases, error cases) matching your repo's style.

### 6. The Bug Hunter
* **Type:** Hosted script (runs 24/7)
* **What it does:** Listens to Sentry or Linear. For every new bug report, reads the stacktrace, opens relevant files, and proposes a fix as a draft PR by morning.

### 7. The Doc Writer
* **Type:** Post-merge hook
* **What it does:** After every merge to main, checks if the change touched anything documented in the README, docstrings, or /docs folder. Updates them in a follow-up PR.

### 8. The Refactor Tracker
* **Type:** Slash command (run weekly)
* **What it does:** Greps your codebase for TODOs, FIXMEs, duplicated logic, and files over 500 lines. Outputs a prioritized refactor list with effort estimates.

### 9. The Daily Standup Agent
* **Type:** Hosted script (runs every morning at 8am)
* **What it does:** Reads your GitHub commits, Linear tickets, and calendar from yesterday. Writes a 4-line summary ("Yesterday: shipped X. Today's blocker: Y.") straight to your email.

### 10. The Customer Feedback Synthesizer
* **Type:** Hosted script (runs weekly)
* **What it does:** Pulls from Intercom, X mentions, and review platforms. Clusters feedback into themes, ranks by frequency, and delivers a Sunday evening brief.

### 11. The Cold Outreach Personalizer
* **Type:** Hosted script (triggered by CRM webhook)
* **What it does:** Looks up new leads' company sites, LinkedIn, and recent posts. Writes personalized cold emails referencing one specific real thing about them and drops them in your drafts.

### 12. The Content Repurposer
* **Type:** Slash command
* **What it does:** Takes one long-form piece and splits it into 3 X posts, 1 LinkedIn post, 1 Telegram note, and 1 newsletter intro—all matching your voice.

### 13. The Inbox Triage Agent
* **Type:** Hosted script (runs every 30 minutes)
* **What it does:** Sorts your email into 4 buckets (reply today, reply this week, FYI, archive). Drafts replies for the first two so you just edit and send.

---

## Infrastructure: Where These Agents Actually Live

* **Locally Hosted (On-Demand):** PR Reviewer, Test Generator, Doc Writer, Refactor Tracker, Content Repurposer. No infrastructure needed.
* **24/7 Managed Hosting:** Bug Hunter, Daily Standup, Customer Feedback, Cold Outreach, Inbox Triage, and your 3 business agents. You need managed infrastructure built specifically for agents so they don't break when your laptop closes.

## The 90-Day Build Plan

Don't try to ship everything in a weekend. Follow this sequence:

* **Week 1:** Research Agent + Operations Agent
* **Week 2:** Content Agent
* **Week 3:** PR Reviewer + Inbox Triage Agent
* **Week 4–6:** Bug Hunter + Daily Standup + Feedback Synthesizer
* **Week 7–10:** Cold Outreach + Content Repurposer + Refactor Tracker

By month 3, you'll have 13 agents running, one human directing, and more output than a team of six at a fraction of the cost.
"""

with open('ai_agents_playbook.md', 'w') as f:
    f.write(markdown_content)
    
print("Markdown file created successfully.")