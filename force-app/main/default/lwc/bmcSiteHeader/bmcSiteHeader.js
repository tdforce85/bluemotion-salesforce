import { LightningElement, api } from "lwc";

export default class BmcSiteHeader extends LightningElement {
  @api homeUrl = "/";
  @api portfolioUrl = "/portfolio";
  @api contactUrl = "/contact";
  @api underTheHoodUrl = "/under-the-hood";
  @api agentforceDemoUrl = "/agentforce-demo";
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
