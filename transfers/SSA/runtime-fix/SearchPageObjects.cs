using System;
using System.Collections.Generic;
using System.Threading;
using MS.Internal.Mita.Logging;
using MS.Internal.Motif.WebDriver;

namespace MS.Internal.Test.Automation.Office.Osg.Wss.Tests
{
    /// <summary>
    /// Base for the Search page objects using only browser-neutral OWebDriver APIs.
    /// </summary>
    public abstract class SPQABasePage : BasePage
    {
        protected IWebDriver _driver;

        public override bool Initialize(IWebDriver driver)
        {
            _driver = driver;
            return true;
        }

        protected bool WaitForCondition(Func<bool> condition, int timeoutSeconds)
        {
            DateTime deadline = DateTime.UtcNow.AddSeconds(timeoutSeconds);
            do
            {
                try { if (condition()) { return true; } }
                catch (WebDriverException) { }
                Thread.Sleep(1000);
            }
            while (DateTime.UtcNow < deadline);
            return false;
        }

        protected string ExecuteJs(string script) => _driver.ExecuteScript(script) ?? string.Empty;
    }

    public class NavItem
    {
        public string Selector { get; set; }
        public string ExpectedTitle { get; set; }
        public string ExpectedUrl { get; set; }
        public string TitleLocator { get; set; }
    }

    public static class SearchNavData
    {
        public static List<NavItem> Get()
        {
            return new List<NavItem>
            {
                new NavItem { Selector = "#ctl00_PlaceHolderLeftNavBar_S2LeftNav_Searchfarmdashboard", ExpectedTitle = "Administer farm-level search settings", ExpectedUrl = "searchfarmdashboard.aspx" },
                new NavItem { Selector = "#ctl00_PlaceHolderLeftNavBar_S2LeftNav_Dashboard", ExpectedTitle = "Search Service Application: Search Administration", ExpectedUrl = "searchadministration.aspx" },
                new NavItem { Selector = "#S2LeftNav_LogContentSources", ExpectedTitle = "Search Service Application: Crawl Log - Content Source", ExpectedUrl = "CrawlLogContentSources.aspx" },
                new NavItem { Selector = "#LeftNav_CrawlHealthReports", ExpectedTitle = "Search Service Application: Crawl Reports - Crawl Rate", ExpectedUrl = "crawlhealthreports.aspx" },
                new NavItem { Selector = "#LeftNav_QueryHealthReports", ExpectedTitle = "Search Service Application: Query Latency Trend", ExpectedUrl = "QueryHealthReports.aspx" },
                new NavItem { Selector = "#LeftNav_UsageReports", ExpectedTitle = "View Usage Reports", ExpectedUrl = "reporting.aspx" },
                new NavItem { Selector = "#S2LeftNav_ListContentSources", ExpectedTitle = "Search Service Application: Manage Content Sources", ExpectedUrl = "listcontentsources.aspx" },
                new NavItem { Selector = "#S2LeftNav_ManageCrawlRules", ExpectedTitle = "Search Service Application: Manage Crawl Rules", ExpectedUrl = "managecrawlrules.aspx" },
                new NavItem { Selector = "#S2LeftNav_ListServerNameMappings", ExpectedTitle = "Search Service Application: Server Name Mappings", ExpectedUrl = "listservernamemappings.aspx" },
                new NavItem { Selector = "#S2LeftNav_ManageFileTypes", ExpectedTitle = "Search Service Application: Manage File Types", ExpectedUrl = "managefiletypes.aspx" },
                new NavItem { Selector = "#S2LeftNav_SearchReset", ExpectedTitle = "Search Service Application: Index Reset", ExpectedUrl = "searchreset.aspx" },
                new NavItem { Selector = "#S2LeftNav_SearchAppPause", ExpectedTitle = "Search Service Application: Pause", ExpectedUrl = "searchapppause.aspx" },
                new NavItem { Selector = "#S2LeftNav_CrawlerImpactRules", ExpectedTitle = "Manage crawler impact rules", ExpectedUrl = "managesitehitrules.aspx" },
                new NavItem { Selector = "#S2LeftNav_EditRelevanceSettings", ExpectedTitle = "Search Service Application: Specify Authoritative Pages", ExpectedUrl = "editrelevancesettings.aspx" },
                new NavItem { Selector = "#S2LeftNav_ManageResultSources", ExpectedTitle = "Search Service Application: Manage Result Sources", ExpectedUrl = "manageresultsourcesssa.aspx" },
                new NavItem { Selector = "#S2LeftNav_ListQueryRules", ExpectedTitle = "Search Service Application: Manage Query Rules", ExpectedUrl = "listqueryrules.aspx" },
                new NavItem { Selector = "#S2LeftNav_ManageQueryClientTypes", ExpectedTitle = "Search Service Application: Manage Query Client Types", ExpectedUrl = "managequeryclienttypesssa.aspx" },
                new NavItem { Selector = "#S2LeftNav_Schema", ExpectedTitle = "Search Service Application: Managed Properties", ExpectedUrl = "listmanagedproperties.aspx" },
                new NavItem { Selector = "#S2LeftNav_QuerySuggestions", ExpectedTitle = "Query Suggestion Settings", ExpectedUrl = "querysuggestionsettings.aspx" },
                new NavItem { Selector = "#S2LeftNav_SearchDictionaries", ExpectedTitle = "Term Store Management Tool", ExpectedUrl = "termstoremanager.aspx" },
                new NavItem { Selector = "#S2LeftNav_SearchResultRemoval", ExpectedTitle = "Search Service Application: Exclude URLs From Search Results", ExpectedUrl = "searchresultremoval.aspx" },
            };
        }
    }

    [ReadyWhen("document.readyState === 'complete'")]
    public sealed class SearchApplicationWebPartPage : SPQABasePage
    {
        public override bool Initialize(IWebDriver driver)
        {
            base.Initialize(driver);
            return driver.Url.ToLower().Contains("serviceapplications.aspx");
        }

        public static SearchApplicationWebPartPage NavigateTo(IWebDriver driver, string adminUrl)
        {
            string url = BuildUrl(adminUrl);
            Log.Comment("Navigating to: {0}", url);
            driver.Navigate(url);
            return driver.InitializePage<SearchApplicationWebPartPage>();
        }

        private static string BuildUrl(string adminUrl)
        {
            string trimmed = adminUrl.TrimEnd('/');
            if (trimmed.EndsWith("/_admin", StringComparison.OrdinalIgnoreCase))
            {
                trimmed = trimmed.Substring(0, trimmed.Length - "/_admin".Length);
            }

            return trimmed + "/_admin/ServiceApplications.aspx";
        }

        public string ResolveSearchAdminUrl()
            => ExecuteJs(
                "(function(){var e=document.querySelector(\"a[href*='searchadministration.aspx']\");return e?e.href:'';})()");
    }

    [ReadyWhen("document.readyState === 'complete'")]
    public sealed class SearchAdministrationWebPartPage : SPQABasePage
    {
        private const string DefaultTitleLocator = "#DeltaPlaceHolderPageTitleInTitleArea";

        public override bool Initialize(IWebDriver driver)
        {
            base.Initialize(driver);
            return driver.Url.ToLower().Contains("searchadministration.aspx");
        }

        public bool IsSearchAdminLoaded()
            => ExecuteJs(
                "(function(){return document.readyState==='complete'&&window.location.href.toLowerCase().indexOf('searchadministration.aspx')>=0?'true':'false';})()") == "true";

        public bool NavigateAndValidate(string selector, string expectedTitle, string expectedUrl, string titleLocator = null)
        {
            if (string.IsNullOrEmpty(selector))
            {
                throw new ArgumentException("A selector is required.", "selector");
            }

            string titleCss = string.IsNullOrEmpty(titleLocator) ? DefaultTitleLocator : titleLocator;
            Log.Comment("Navigating using selector: {0}", selector);
            try
            {
                string clickResult = ExecuteJs(
                    "(function(){var e=document.querySelector('" + EscapeJs(selector) +
                    "');if(!e){return 'missing';}e.click();return 'clicked';})()");
                if (!string.Equals(clickResult, "clicked", StringComparison.OrdinalIgnoreCase))
                {
                    Log.Warning("{0}", string.Format(
                        "Validation failed at selector stage | Selector: {0} | Result: {1} | URL: {2}",
                        selector, clickResult, SafeUrl()));
                    return false;
                }

                if (!WaitForCondition(() => SafeUrl().IndexOf(expectedUrl, StringComparison.OrdinalIgnoreCase) >= 0, 20))
                {
                    Log.Warning("{0}", string.Format(
                        "Validation failed at URL stage | Selector: {0} | Expected URL to contain: '{1}' | Actual URL: {2}",
                        selector, expectedUrl, SafeUrl()));
                    return false;
                }

                string titleScript = "(function(){var e=document.querySelector('" + EscapeJs(titleCss) + "');return e?(e.textContent||e.innerText||''):'';})()";
                if (!WaitForCondition(() => !string.IsNullOrEmpty(ExecuteJs(titleScript)), 10))
                {
                    Log.Warning("{0}", string.Format(
                        "Validation failed at title-element stage | Selector: {0} | Title locator '{1}' never appeared | URL: {2}",
                        selector, titleCss, SafeUrl()));
                    return false;
                }

                string actualTitle = ExecuteJs(titleScript);
                if (actualTitle == null || !actualTitle.Contains(expectedTitle))
                {
                    Log.Warning("{0}", string.Format(
                        "Validation failed at title-text stage | Selector: {0} | Expected title to contain: '{1}' | Actual title: '{2}' | URL: {3}",
                        selector, expectedTitle, actualTitle ?? "(null)", SafeUrl()));
                    return false;
                }

                Log.Comment("Navigation validated | URL: {0}", SafeUrl());
                return true;
            }
            catch (Exception ex)
            {
                Log.Warning("{0}", string.Format(
                    "Navigation exception | Selector: {0} | {1}: {2} | URL: {3}",
                    selector, ex.GetType().Name, ex.Message, SafeUrl()));
                return false;
            }
        }

        private string SafeUrl()
        {
            try { return _driver.Url; }
            catch (Exception ex) { return "(unavailable: " + ex.GetType().Name + ")"; }
        }

        private static string EscapeJs(string value)
        {
            return value.Replace("\\", "\\\\").Replace("'", "\\'");
        }
    }
}