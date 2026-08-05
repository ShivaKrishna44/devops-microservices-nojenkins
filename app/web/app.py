"""
DevOps AI Agent — Web Dashboard
================================
A simple web UI where engineers can:
- Trigger health checks on demand
- View historical reports
- See status per commit/deployment

Run: uvicorn web.app:app --reload --port 8000
Open: http://localhost:8000
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, BackgroundTasks
from fastapi.responses import HTMLResponse

# Add parent dir to path so we can import agent modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from config import settings, logger

app = FastAPI(title="DevOps AI Agent Dashboard")

# Store reports in a JSON file (simple — no DB needed)
REPORTS_FILE = Path(__file__).parent / "reports.json"


def load_reports() -> list:
    """Load saved reports from file."""
    if REPORTS_FILE.exists():
        return json.loads(REPORTS_FILE.read_text())
    return []


def save_report(report: dict):
    """Save a new report to file."""
    reports = load_reports()
    reports.insert(0, report)  # newest first
    reports = reports[:50]  # keep last 50 reports only
    REPORTS_FILE.write_text(json.dumps(reports, indent=2, default=str))


def run_agent_check() -> dict:
    """Run the multi-agent health check and return results."""
    from graph.multi_agent import build_multi_agent
    from langchain_core.messages import HumanMessage, AIMessage

    agent = build_multi_agent()

    query = (
        f"Perform a comprehensive infrastructure health check for '{settings.TARGET_REPO}'. "
        f"Check ALL of the following:\n"
        f"1. GitHub Actions — any failed workflow runs?\n"
        f"2. AWS EC2 — all instances healthy and running?\n"
        f"3. Kubernetes pods — any pods NOT in Running state?\n"
        f"4. Kubernetes nodes — any nodes NotReady?\n"
        f"5. Kubernetes deployments — any with missing replicas?\n"
        f"6. Cost — any idle EC2 instances (< 5% CPU)?\n"
        f"7. Cost — any unattached EBS volumes?\n"
        f"8. Cost — what's the current month AWS spend?\n"
        f"Report each check with PASS or FAIL status."
    )

    inputs = {
        "messages": [HumanMessage(content=query)],
        "next_agent": "",
        "results": {},
    }

    # Run agent
    final_output = {}
    for output in agent.stream(inputs, config={"callbacks": []}, stream_mode="values"):
        if output.get("results"):
            final_output = output["results"]
        last_msg = output.get("messages", [None])[-1] if output.get("messages") else None
        if isinstance(last_msg, AIMessage) and last_msg.content and "===" in last_msg.content:
            final_output["summary"] = last_msg.content

    # Determine individual check statuses
    checks = {
        "github_actions": "pass",
        "aws_ec2": "pass",
        "k8s_pods": "pass",
        "k8s_nodes": "pass",
        "k8s_deployments": "pass",
        "cost_idle_instances": "pass",
        "cost_ebs_volumes": "pass",
        "cost_summary": "info",
    }

    for key, value in final_output.items():
        val_str = str(value).lower()
        if "alert" in val_str or "fail" in val_str or "unhealthy" in val_str or "failed" in val_str:
            if "github" in key or "aws_agent" in key:
                if "failed" in val_str or "failure" in val_str:
                    checks["github_actions"] = "fail"
            if "k8s" in key:
                if "unreachable" in val_str or "error" in val_str:
                    checks["k8s_pods"] = "unreachable"
                    checks["k8s_nodes"] = "unreachable"
                    checks["k8s_deployments"] = "unreachable"
                elif "alert" in val_str:
                    checks["k8s_pods"] = "fail"
            if "cost" in key:
                if "idle" in val_str and "alert" in val_str:
                    checks["cost_idle_instances"] = "warn"
                if "unattached" in val_str and "alert" in val_str:
                    checks["cost_ebs_volumes"] = "warn"

    # Overall status
    if any(v == "fail" for v in checks.values()):
        overall = "critical"
    elif any(v == "warn" for v in checks.values()):
        overall = "warning"
    elif any(v == "unreachable" for v in checks.values()):
        overall = "degraded"
    else:
        overall = "healthy"

    report = {
        "timestamp": datetime.now().isoformat(),
        "results": final_output,
        "checks": checks,
        "repo": settings.TARGET_REPO,
        "status": overall,
    }

    save_report(report)
    return report


# ═══════════════════════════════════════════
# API Endpoints
# ═══════════════════════════════════════════

def _status_icon(status: str) -> str:
    """Return emoji for status."""
    icons = {"pass": "🟢", "fail": "🔴", "warn": "🟡", "unreachable": "⚪", "info": "🔵"}
    return icons.get(status, "⚪")


def _build_health_grid(report: dict) -> str:
    """Build HTML grid showing individual check statuses."""
    if not report or "checks" not in report:
        return '<p style="color:#666">No health data yet. Run a check first.</p>'

    checks = report["checks"]
    check_labels = {
        "github_actions": "GitHub Actions",
        "aws_ec2": "AWS EC2 Health",
        "k8s_pods": "K8s Pods",
        "k8s_nodes": "K8s Nodes",
        "k8s_deployments": "K8s Deployments",
        "cost_idle_instances": "Idle Instances",
        "cost_ebs_volumes": "EBS Volumes",
        "cost_summary": "Cost Summary",
    }

    grid = ""
    for key, label in check_labels.items():
        status = checks.get(key, "unknown")
        icon = _status_icon(status)
        bg = "#1b3a1b" if status == "pass" else "#3a1b1b" if status == "fail" else "#3a3a1b" if status == "warn" else "#1b1b2e"
        grid += f'<div class="check-card" style="background:{bg}"><span class="check-icon">{icon}</span><span class="check-label">{label}</span><span class="check-status">{status.upper()}</span></div>'

    return grid


@app.get("/", response_class=HTMLResponse)
async def dashboard():
    """Main dashboard — shows all reports."""
    reports = load_reports()

    rows = ""
    for r in reports[:20]:
        timestamp = r.get("timestamp", "unknown")[:19]
        status = r.get("status", "unknown")
        status_icons = {"healthy": "🟢", "critical": "🔴", "warning": "🟡", "degraded": "⚪"}
        status_icon = status_icons.get(status, "⚪")
        repo = r.get("repo", "")
        results = r.get("results", {})

        # Build results summary
        details = ""
        for agent_name, result in results.items():
            if agent_name == "summary":
                continue
            short = str(result)[:100].replace("<", "&lt;").replace(">", "&gt;")
            details += f"<b>{agent_name}:</b> {short}<br>"

        rows += f"""
        <tr>
            <td>{status_icon} {status}</td>
            <td>{timestamp}</td>
            <td>{repo}</td>
            <td style="font-size:12px">{details}</td>
        </tr>
        """

    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>DevOps AI Agent — Dashboard</title>
        <style>
            body {{ font-family: -apple-system, sans-serif; margin: 40px; background: #1a1a2e; color: #eee; }}
            h1 {{ color: #00d4aa; }}
            table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
            th {{ background: #16213e; padding: 12px; text-align: left; }}
            td {{ padding: 10px; border-bottom: 1px solid #333; }}
            tr:hover {{ background: #16213e; }}
            .btn {{ background: #00d4aa; color: #000; padding: 12px 24px; border: none;
                    border-radius: 6px; cursor: pointer; font-size: 16px; font-weight: bold; }}
            .btn:hover {{ background: #00b894; }}
            .header {{ display: flex; justify-content: space-between; align-items: center; }}
            .stats {{ display: flex; gap: 20px; margin: 20px 0; }}
            .stat-box {{ background: #16213e; padding: 20px; border-radius: 8px; text-align: center; }}
            .stat-num {{ font-size: 32px; color: #00d4aa; }}
            .health-grid {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin: 20px 0; }}
            .check-card {{ padding: 16px; border-radius: 8px; display: flex; flex-direction: column; align-items: center; gap: 8px; }}
            .check-icon {{ font-size: 28px; }}
            .check-label {{ font-size: 13px; color: #aaa; }}
            .check-status {{ font-size: 11px; font-weight: bold; letter-spacing: 1px; }}
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🤖 DevOps AI Agent Dashboard</h1>
            <form action="/run" method="get">
                <button class="btn" type="submit">▶ Run Health Check Now</button>
            </form>
        </div>

        <div class="stats">
            <div class="stat-box">
                <div class="stat-num">{len(reports)}</div>
                <div>Total Reports</div>
            </div>
            <div class="stat-box">
                <div class="stat-num">{sum(1 for r in reports if r.get('status') == 'healthy')}</div>
                <div>Healthy</div>
            </div>
            <div class="stat-box">
                <div class="stat-num">{sum(1 for r in reports if r.get('status') in ('critical', 'warning', 'degraded'))}</div>
                <div>Issues</div>
            </div>
        </div>

        <!-- Latest Health Check Status Grid -->
        <h2>Current Health Status</h2>
        <div class="health-grid">
            {_build_health_grid(reports[0] if reports else None)}
        </div>

        <h2>Recent Reports</h2>
        <table>
            <tr>
                <th>Status</th>
                <th>Time</th>
                <th>Repository</th>
                <th>Details</th>
            </tr>
            {rows if rows else '<tr><td colspan="4">No reports yet. Click "Run Health Check Now" to start.</td></tr>'}
        </table>

        <p style="margin-top:40px; color:#666;">
            Agent checks: GitHub Actions, AWS EC2, Kubernetes, Cost Optimization<br>
            Reports stored locally. Refresh page to see latest.
        </p>
    </body>
    </html>
    """
    return HTMLResponse(content=html)


@app.get("/run", response_class=HTMLResponse)
async def run_check():
    """Trigger a new health check and redirect back to dashboard."""
    try:
        report = run_agent_check()
        status = report.get("status", "unknown")
        message = f"Health check complete. Status: {status}"
    except Exception as e:
        message = f"Agent run failed: {e}"
        logger.error("Web agent run failed: %s", e)

    html = f"""
    <html>
    <head>
        <meta http-equiv="refresh" content="3;url=/" />
        <style>
            body {{ font-family: sans-serif; text-align: center; margin-top: 100px; background: #1a1a2e; color: #eee; }}
        </style>
    </head>
    <body>
        <h2>✅ {message}</h2>
        <p>Redirecting to dashboard in 3 seconds...</p>
        <a href="/" style="color:#00d4aa;">Go to Dashboard</a>
    </body>
    </html>
    """
    return HTMLResponse(content=html)


@app.get("/api/reports")
async def api_reports():
    """API endpoint — returns reports as JSON (for integrations)."""
    return load_reports()


@app.get("/api/latest")
async def api_latest():
    """API endpoint — returns the most recent report."""
    reports = load_reports()
    return reports[0] if reports else {"message": "No reports yet"}
