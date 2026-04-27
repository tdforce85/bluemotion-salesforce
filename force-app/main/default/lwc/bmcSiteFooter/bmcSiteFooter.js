import { LightningElement, api } from "lwc";

export default class BmcSiteFooter extends LightningElement {
  @api githubUrl = "https://github.com/tdforce85/bluemotion-salesforce";
  @api linkedInUrl = "https://www.linkedin.com/in/tonydegregorio";
  @api personalSiteUrl = "https://tonydegregorio.com";
  @api tagline = "Built on Salesforce Experience Cloud LWR.";

  get currentYear() {
    return new Date().getFullYear();
  }
}
