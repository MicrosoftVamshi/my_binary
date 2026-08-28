using System;
using MS.Internal.Motif.WebDriver;
using MS.Internal.Motif.Runtime;
using MS.Internal.Motif.Runtime.TestAttributes;
using MS.Internal.Mita.Logging;
using MS.Internal.Test.Automation.Office.OSG.WSS.TestClasses;
using Microsoft.SharePoint.Administration;

namespace MS.Internal.Test.Automation.Office.Osg.Wss.Tests
{
    /// <summary>
    /// End-to-end UI test for the SharePoint Search Service Application (SSA) admin surface.
    /// It drives Chrome through every left-nav page of Search
    /// Administration and verifies each lands on the expected URL with the expected page title.
    /// </summary>
    /// <remarks>
    /// Uses the WSS client lifecycle but keeps setup focused on Central Administration. The CloudTest scenario
    /// disables the unrelated content-site health probe, while SearchTestBaseClass would add destructive search
    /// reset and crawl setup that this UI-only test does not need.
    /// </remarks>
    [TestClass]
    public class SearchServiceApplication : WSSClientTestClass
    {
        // The OWebDriver-owned browser for the whole test. Created in Initialize, disposed in CleanUp.
        private IWebDriver _driver;
        private string _targetAdminUrl;

        public SearchServiceApplication()
        {
        }

        /// <summary>
        /// Test setup: launch the browser through DriverFactory.
        /// </summary>
        [Setup]
        [Timeout(1800)]
        public override void Initialize()
        {
            base.Initialize();
            _targetAdminUrl = SPAdministrationWebApplication.Local
                .GetResponseUri(SPUrlZone.Default)
                .ToString();
            _driver = DriverFactory.Create(BrowserName.Chrome);
            Log.VerifyTrue(_driver != null, "Chrome driver created");
        }

        /// <summary>
        /// Navigates to every Search Administration page listed in <see cref="SearchNavData"/> and
        /// verifies the resulting URL and page title match expectations.
        /// </summary>
        [TestMethod]
        [TestDescription("[12086281] Verify every Search Administration left-nav page loads with the expected URL and title")]
        [Timeout(600)]
        public void Check_SearchServiceApplication()
        {
            // The 21 left-nav pages to visit, each with its selector + expected URL/title.
            var navigationChecks = SearchNavData.Get();
            Log.VerifyTrue(navigationChecks.Count > 0, "Navigation data is not empty");

            // Resolve the Search Administration URL once so each iteration navigates
            // directly to it instead of going through the Service Applications page.
            string searchAdminUrl;
            using (var home = SearchApplicationWebPartPage.NavigateTo(_driver, _targetAdminUrl))
            {
                searchAdminUrl = home.ResolveSearchAdminUrl();
            }

            // Stop here rather than looping 21 times against an empty URL: without this the log fills with
            // cascading navigation failures that hide the real cause (no SSA link on the page).
            if (string.IsNullOrEmpty(searchAdminUrl))
            {
                Log.Fail("{0}", string.Format(
                    "Could not resolve the Search Administration URL from {0}/_admin/ServiceApplications.aspx. " +
                    "The Search Service Application link is missing, which usually means the SSA is not provisioned " +
                    "or its proxy is not started. Skipping the {1} navigation checks.",
                    _targetAdminUrl, navigationChecks.Count.ToString()));
                return;
            }

            Log.Comment("Search Administration URL: {0}", searchAdminUrl);

            // For each page: return to the Search Admin landing page, click the nav item, and validate.
            // Re-navigating each iteration keeps every check independent of the previous page's state.
            int failures = 0;
            foreach (var item in navigationChecks)
            {
                _driver.Navigate(searchAdminUrl);
                using (var searchPage = _driver.InitializePage<SearchAdministrationWebPartPage>())
                {
                    if (!searchPage.IsSearchAdminLoaded())
                    {
                        failures++;
                        Log.Fail("{0}", string.Format(
                            "Search Admin landing page did not load before checking '{0}'. Current URL: {1}",
                            item.Selector, _driver.Url));
                        continue;
                    }

                    Log.Comment("Expected Title: {0}", item.ExpectedTitle);
                    Log.Comment("Expected URL: {0}", item.ExpectedUrl);

                    bool isValid = searchPage.NavigateAndValidate(
                        item.Selector,
                        item.ExpectedTitle,
                        item.ExpectedUrl,
                        item.TitleLocator
                    );

                    if (!isValid)
                    {
                        failures++;
                    }

                    Log.VerifyTrue(isValid, "Validation passed | " + item.Selector);
                }
            }

            Log.Comment("{0}", string.Format("Navigation checks complete: {0} of {1} passed.",
                (navigationChecks.Count - failures).ToString(), navigationChecks.Count.ToString()));
        }

        /// <summary>
        /// Teardown: close the browser, then run base cleanup.
        /// </summary>
        /// <remarks>
        /// A browser that already died must not prevent base cleanup.
        /// </remarks>
        [Teardown]
        public override void CleanUp()
        {
            try
            {
                if (_driver != null) { _driver.Dispose(); }
            }
            catch (Exception ex)
            {
                // Warning, not Comment: Comment lines are filtered out of the result log.
                Log.Warning("{0}", string.Format(
                    "Browser dispose failed during teardown: {0}: {1}", ex.GetType().Name, ex.Message));
            }
            finally
            {
                _driver = null;
                base.CleanUp();
            }
        }
    }
}
