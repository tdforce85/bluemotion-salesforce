import { LightningElement, track } from "lwc";
import getErrorSummary from "@salesforce/apex/ErrorLogController.getErrorSummary";
import getRecentErrors from "@salesforce/apex/ErrorLogController.getRecentErrors";
import getErrorsBySource from "@salesforce/apex/ErrorLogController.getErrorsBySource";

const SEVERITY_ORDER  = ["Critical", "High", "Medium", "Low", "Info"];
const SEVERITY_SLUG   = { Critical: "critical", High: "high", Medium: "medium", Low: "low", Info: "info" };
const POLL_INTERVAL_MS = 30000;

export default class BmcErrorDashboard extends LightningElement {
  @track isLoading      = false;
  @track lastRefreshed  = "";
  @track severityCards  = [];
  @track recentErrors   = [];
  @track sourceChartData = [];
  @track hasSourceData  = false;
  @track hasRecentErrors = false;

  _pollInterval = null;

  connectedCallback() {
    this.loadData();
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._pollInterval = setInterval(() => {
      this.loadData();
    }, POLL_INTERVAL_MS);
  }

  disconnectedCallback() {
    if (this._pollInterval) {
      clearInterval(this._pollInterval);
    }
  }

  async loadData() {
    this.isLoading = true;
    try {
      const [summary, recent, bySource] = await Promise.all([
        getErrorSummary(),
        getRecentErrors(),
        getErrorsBySource()
      ]);
      this.processSummary(summary);
      this.processRecentErrors(recent);
      this.processSourceData(bySource);
      this.lastRefreshed = "Last refreshed: " + new Date().toLocaleTimeString();
    } catch (e) {
      console.error("bmcErrorDashboard: data load failed", e);
    } finally {
      this.isLoading = false;
    }
  }

  processSummary(data) {
    const countMap = {};
    (data || []).forEach((s) => { countMap[s.severity] = s.count; });
    this.severityCards = SEVERITY_ORDER.map((sev) => ({
      severity:  sev,
      count:     countMap[sev] || 0,
      cardClass: `severity-card severity-card--${SEVERITY_SLUG[sev]}`
    }));
  }

  processRecentErrors(data) {
    this.hasRecentErrors = data && data.length > 0;
    this.recentErrors = (data || []).map((err) => ({
      ...err,
      formattedTime:      this.formatTime(err.Occurred_At__c),
      rowClass:           `error-row error-row--${SEVERITY_SLUG[err.Severity__c] || "info"}`,
      severityBadgeClass: `severity-badge severity-badge--${SEVERITY_SLUG[err.Severity__c] || "info"}`,
      locationLabel:      [err.Class_Name__c, err.Method_Name__c].filter(Boolean).join(".")
    }));
  }

  processSourceData(data) {
    this.hasSourceData = data && data.length > 0;
    if (!this.hasSourceData) return;
    const max = Math.max(...data.map((s) => s.count));
    this.sourceChartData = data.map((s) => ({
      ...s,
      barStyle: `width: ${max > 0 ? Math.round((s.count / max) * 100) : 0}%`
    }));
  }

  formatTime(isoString) {
    if (!isoString) return "";
    const d = new Date(isoString);
    return (
      d.toLocaleDateString() +
      " " +
      d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    );
  }
}
