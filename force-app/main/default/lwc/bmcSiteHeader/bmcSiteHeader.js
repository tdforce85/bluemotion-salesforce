import { LightningElement, api } from "lwc";

export default class BmcSiteHeader extends LightningElement {
  @api homeUrl = "/";
  @api overEngineeredLeadFormUrl = "/";
  @api errorHandlingDashboardUrl = "/";
  @api externalLinkUrl = "https://tonydegregorio.com";
  @api externalLinkLabel = "tonydegregorio.com";

  menuOpen = false;

  get navClass() {
    return this.menuOpen ? "nav nav--open" : "nav";
  }

  handleToggleMenu() {
    this.menuOpen = !this.menuOpen;
  }

  handleNavClick() {
    this.menuOpen = false;
  }
}
