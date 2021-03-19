import UIKit
import XRatesKit
import RxSwift
import ThemeKit
import SectionsTableView
import SnapKit
import HUD
import Chart

class CoinPageViewController: ThemeViewController {
    private let viewModel: CoinPageViewModel
    private let chartViewModel: CoinChartViewModel
    private var urlManager: IUrlManager
    private let disposeBag = DisposeBag()

    private var state: CoinPageViewModel.State = .loading

    private let tableView = SectionsTableView(style: .grouped)
    private let subtitleCell = AdditionalDataCell()

    /* Chart section */
    private let currentRateCell: CoinChartRateCell
    private let chartIntervalAndSelectedRateCell = ChartIntervalAndSelectedRateCell()
    private let chartViewCell: ChartViewCell
    private let indicatorSelectorCell = IndicatorSelectorCell()

    /* Description */
    private let descriptionTextCell = ReadMoreTextCell()

    init(viewModel: CoinPageViewModel, chartViewModel: CoinChartViewModel, configuration: ChartConfiguration, urlManager: IUrlManager) {
        self.viewModel = viewModel
        self.chartViewModel = chartViewModel
        self.urlManager = urlManager

        currentRateCell = CoinChartRateCell(viewModel: chartViewModel)
        chartViewCell = ChartViewCell(configuration: configuration)

        super.init()

        chartViewCell.delegate = chartViewModel

        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        title = viewModel.title

        tableView.sectionDataSource = self

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear

        tableView.registerCell(forClass: A1Cell.self)
        tableView.registerCell(forClass: B1Cell.self)
        tableView.registerCell(forClass: B4Cell.self)
        tableView.registerCell(forClass: D7Cell.self)
        tableView.registerCell(forClass: D9Cell.self)
        tableView.registerCell(forClass: ReturnOfInvestmentsTableViewCell.self)
        tableView.registerCell(forClass: PriceIndicatorCell.self)
        tableView.registerCell(forClass: ChartMarketPerformanceCell.self)
        tableView.registerCell(forClass: TitledHighlightedDescriptionCell.self)
        tableView.registerCell(forClass: BrandFooterCell.self)
        tableView.registerCell(forClass: SpinnerCell.self)
        tableView.registerCell(forClass: ErrorCell.self)

        chartIntervalAndSelectedRateCell.bind(filters: chartViewModel.chartTypes.map {
            .item(title: $0)
        })
        chartIntervalAndSelectedRateCell.onSelectInterval = { [weak self] index in
            self?.chartViewModel.onSelectType(at: index)
        }

        indicatorSelectorCell.onTapIndicator = { [weak self] indicator in
            self?.chartViewModel.onTap(indicator: indicator)
        }

        descriptionTextCell.set(backgroundStyle: .transparent, isFirst: true)
        descriptionTextCell.onChangeHeight = { [weak self] in
            self?.reloadTable()
        }

        subtitleCell.bind(title: viewModel.subtitle, value: nil)
        subscribeViewModels()
    }

    override func viewWillAppear(_ animated: Bool) {
        tableView.deselectCell(withCoordinator: transitionCoordinator, animated: animated)
    }

    private func subscribeViewModels() {
        subscribe(disposeBag, viewModel.stateDriver) { [weak self] in self?.sync(state: $0) }

        // chart section
        subscribe(disposeBag, chartViewModel.pointSelectModeEnabledDriver) { [weak self] in
            self?.syncChart(selected: $0)
        }
        subscribe(disposeBag, chartViewModel.pointSelectedItemDriver) { [weak self] in
            self?.syncChart(selectedViewItem: $0)
        }
        subscribe(disposeBag, chartViewModel.chartTypeIndexDriver) { [weak self] in
            self?.syncChart(typeIndex: $0)
        }
        subscribe(disposeBag, chartViewModel.loadingDriver) { [weak self] in
            self?.syncChart(loading: $0)
        }
        subscribe(disposeBag, chartViewModel.errorDriver) { [weak self] in
            self?.syncChart(error: $0)
        }
        subscribe(disposeBag, chartViewModel.chartInfoDriver) { [weak self] in
            self?.syncChart(viewItem: $0)
        }
    }

    private func reloadTable() {
        tableView.buildSections()

        UIView.animate(withDuration: 0.2) {
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }
    }

}

extension CoinPageViewController {

    private func sync(state: CoinPageViewModel.State) {
        self.state = state
        tableView.reload()
    }

    // Chart section

    private func deactivateIndicators() {
        ChartIndicatorSet.all.forEach { indicator in
            indicatorSelectorCell.bind(indicator: indicator, selected: false)
        }
    }

    private func syncChart(viewItem: CoinChartViewModel.ViewItem?) {
        guard let viewItem = viewItem else {
            return
        }

        chartViewCell.set(data: viewItem)
        chartViewCell.setVolumes(hidden: viewItem.selectedIndicator.hideVolumes)

        ChartIndicatorSet.all.forEach { indicator in
            let show = viewItem.selectedIndicator.contains(indicator)

            chartViewCell.bind(indicator: indicator, hidden: !show)

            indicatorSelectorCell.bind(indicator: indicator, selected: show)
        }
    }

    private func syncChart(selected: Bool) {
        chartIntervalAndSelectedRateCell.bind(displayMode: selected ? .selectedRate : .interval)
    }

    private func syncChart(selectedViewItem: SelectedPointViewItem?) {
        guard let viewItem = selectedViewItem else {
            return
        }
        chartIntervalAndSelectedRateCell.bind(selectedPointViewItem: viewItem)
    }

    private func syncChart(typeIndex: Int) {
        chartIntervalAndSelectedRateCell.select(index: typeIndex)
    }

    private func syncChart(loading: Bool) {
        if loading {
            chartViewCell.showLoading()
            deactivateIndicators()
        } else {
            chartViewCell.hideLoading()
        }
    }

    private func syncChart(error: String?) { //todo: check logic!
        if error != nil {
            deactivateIndicators()
        }
    }

}

extension CoinPageViewController {

    private var subtitleSection: SectionProtocol {
        Section(id: "subtitle",
                rows: [StaticRow(
                        cell: subtitleCell,
                        id: "subtitle",
                        height: AdditionalDataCell.height
                )])
    }

    private var chartSection: SectionProtocol {
        Section(
                id: "chart",
                rows: [
                    StaticRow(
                            cell: currentRateCell,
                            id: "currentRate",
                            height: ChartCurrentRateCell.cellHeight),
                    StaticRow(
                            cell: chartIntervalAndSelectedRateCell,
                            id: "chartIntervalAndSelectedRate",
                            height: .heightSingleLineCell),
                    StaticRow(
                            cell: chartViewCell,
                            id: "chartView",
                            height: ChartViewCell.cellHeight),
                    StaticRow(
                            cell: indicatorSelectorCell,
                            id: "indicatorSelector",
                            height: .heightSingleLineCell),
                ])
    }

    private func headerRow(title: String) -> RowProtocol {
        Row<B4Cell>(
                id: "header_cell",
                hash: title,
                height: .heightSingleLineCell,
                bind: { cell, _ in
                    cell.set(backgroundStyle: .transparent)
                    cell.title = title
                    cell.selectionStyle = .none
                })
    }

    private func descriptionSection(description: String) -> SectionProtocol {
        descriptionTextCell.contentText = description

        return Section(
                id: "description",
                headerState: .margin(height: .margin12),
                rows: [
                    headerRow(title: "chart.about.header".localized),
                    StaticRow(
                            cell: descriptionTextCell,
                            id: "about_cell",
                            dynamicHeight: { [weak self] containerWidth in
                                self?.descriptionTextCell.cellHeight(containerWidth: containerWidth) ?? 0
                            }
                    )
                ])
    }

    private func linksSection(guideUrl: URL?, links: [CoinPageViewModel.Link]) -> SectionProtocol {
        var guideRows = [RowProtocol]()

        if let guideUrl = guideUrl {
            let isLast = links.isEmpty

            let guideRow = Row<A1Cell>(
                    id: "guide",
                    height: .heightCell48,
                    bind: { cell, _ in
                        cell.set(backgroundStyle: .lawrence, isFirst: true, isLast: isLast)
                        cell.titleImage = UIImage(named: "academy_1_20")
                        cell.title = "coin_page.guide".localized
                    },
                    action: { [weak self] _ in
                        let module = MarkdownModule.viewController(url: guideUrl)
                        self?.navigationController?.pushViewController(module, animated: true)
                    }
            )

            guideRows.append(guideRow)
        }

        return Section(
                id: "links",
                headerState: .margin(height: .margin12),
                rows: guideRows + links.enumerated().map { index, link in
                    let isFirst = guideRows.isEmpty && index == 0
                    let isLast = index == links.count - 1

                    return Row<A1Cell>(
                            id: link.type.rawValue,
                            height: .heightCell48,
                            autoDeselect: true,
                            bind: { cell, _ in
                                cell.set(backgroundStyle: .lawrence, isFirst: isFirst, isLast: isLast)
                                cell.titleImage = link.icon
                                cell.title = link.title
                            },
                            action: { [weak self] _ in
                                self?.open(link: link)
                            }
                    )
                }
        )
    }

    private func open(link: CoinPageViewModel.Link) {
        urlManager.open(url: link.url, from: self)
    }

    private func poweredBySection(text: String) -> SectionProtocol {
        Section(
                id: "powered-by",
                headerState: .margin(height: .margin32),
                rows: [
                    Row<BrandFooterCell>(
                            id: "powered-by",
                            dynamicHeight: { containerWidth in
                                BrandFooterCell.height(containerWidth: containerWidth, title: text)
                            },
                            bind: { cell, _ in
                                cell.title = text
                            }
                    )
                ]
        )
    }

    private func marketsSection(fundCategories: [CoinFundCategory], tickers: [MarketTicker]) -> SectionProtocol? {
        var rows = [RowProtocol]()

        let hasMarkets = !tickers.isEmpty
        let hasInvestors = !fundCategories.isEmpty

        if !tickers.isEmpty {
            let marketsTitle = "coin_page.markets".localized(viewModel.coinCode)
            let marketsRow = Row<B1Cell>(
                    id: "markets",
                    height: .heightCell48,
                    autoDeselect: true,
                    bind: { cell, _ in
                        cell.set(backgroundStyle: .lawrence, isFirst: true, isLast: !hasInvestors)
                        cell.title = marketsTitle
                    },
                    action: { [weak self] _ in
                        self?.openMarkets(tickers: tickers)
                    }
            )

            rows.append(marketsRow)
        }

        if !fundCategories.isEmpty {
            let investorsTitle = "coin_page.investors".localized(viewModel.coinCode)
            let investorsRow = Row<B1Cell>(
                    id: "investors",
                    height: .heightCell48,
                    bind: { cell, _ in
                        cell.set(backgroundStyle: .lawrence, isFirst: !hasMarkets, isLast: true)
                        cell.title = investorsTitle
                    },
                    action: { [weak self] _ in
                        self?.openInvestors(fundCategories: fundCategories)
                    }
            )

            rows.append(investorsRow)
        }

        if !rows.isEmpty {
            return Section(id: "markets", headerState: .margin(height: .margin12), rows: rows)
        } else {
            return nil
        }
    }

    private func openMarkets(tickers: [MarketTicker]) {
        let viewController = CoinMarketsModule.viewController(coinCode: viewModel.coinCode, tickers: tickers)
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func openInvestors(fundCategories: [CoinFundCategory]) {
        let viewController = CoinInvestorsModule.viewController(coinCode: viewModel.coinCode, fundCategories: fundCategories)
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func returnOfInvestmentsSection(viewItems: [[CoinPageViewModel.ReturnOfInvestmentsViewItem]]) -> SectionProtocol {
        Section(
                id: "return_of_investments_section",
                headerState: .margin(height: .margin12),
                rows: [
                    Row<ReturnOfInvestmentsTableViewCell>(
                            id: "return_of_investments_cell",
                            dynamicHeight: { [weak self] _ in
                                ReturnOfInvestmentsTableViewCell.height(viewItems: viewItems)
                            },
                            bind: { cell, _ in
                                cell.bind(viewItems: viewItems)
                            }
                    )
                ]
        )
    }

    private func categoriesSection(categories: [String]?, contractInfo: CoinPageViewModel.ContractInfo?) -> SectionProtocol? {
        var rows = [RowProtocol]()

        let hasCategories = categories != nil
        let hasContractInfo = contractInfo != nil

        if let categories = categories {
            let categoriesRow = Row<D7Cell>(
                    id: "categories",
                    height: .heightCell48,
                    bind: { cell, _ in
                        cell.set(backgroundStyle: .lawrence, isFirst: true, isLast: !hasContractInfo)
                        cell.title = "coin_page.categories".localized
                        cell.value = categories.joined(separator: ", ")
                    }
            )

            rows.append(categoriesRow)
        }

        if let contractInfo = contractInfo {
            let contractInfoRow = Row<D9Cell>(
                    id: "investors",
                    height: .heightCell48,
                    bind: { cell, _ in
                        cell.set(backgroundStyle: .lawrence, isFirst: !hasCategories, isLast: true)
                        cell.title = contractInfo.title
                        cell.viewItem = CopyableSecondaryButton.ViewItem(value: contractInfo.value)
                    }
            )

            rows.append(contractInfoRow)
        }

        if !rows.isEmpty {
            return Section(id: "categories-contact-info", headerState: .margin(height: .margin12), rows: rows)
        } else {
            return nil
        }
    }

    private func marketRow(id: String, title: String, text: String, isFirst: Bool, isLast: Bool) -> RowProtocol {
        Row<D7Cell>(
                id: id,
                height: .heightCell48,
                bind: { cell, _ in
                    cell.set(backgroundStyle: .lawrence, isFirst: isFirst, isLast: isLast)
                    cell.title = title
                    cell.value = text
                }
        )
    }

    private func marketInfoSection(marketInfo: CoinPageViewModel.MarketInfo) -> SectionProtocol? {
        var datas = [
            marketInfo.marketCap.map { (id: "market_cap", title: "coin_page.market_cap".localized, text: $0) },
            marketInfo.volume24h.map { (id: "volume_24h", title: "coin_page.volume_24h".localized, text: $0) },
            marketInfo.circulatingSupply.map { (id: "circulating_supply", title: "coin_page.circulating_supply".localized, text: $0) },
            marketInfo.totalSupply.map { (id: "total_supply", title: "coin_page.total_supply".localized, text: $0) },
            marketInfo.dillutedMarketCap.map { (id: "dilluted_m_cap", title: "coin_page.dilluted_market_cap".localized, text: $0) }
        ].compactMap { $0 }

        guard !datas.isEmpty else {
            return nil
        }

        var rows = datas.enumerated().map { index, tuple in
            marketRow(
                    id: tuple.id,
                    title: tuple.title,
                    text: tuple.text,
                    isFirst: index == 0,
                    isLast: index == datas.count - 1
            )
        }


        return Section(
            id: "market_info_section",
            headerState: .margin(height: .margin12),
            rows: rows
        )
    }

    private var spinnerSection: SectionProtocol {
        Section(
                id: "spinner",
                rows: [
                    Row<SpinnerCell>(
                            id: "spinner",
                            height: 100
                    )
                ]
        )
    }

    private func errorSection(text: String) -> SectionProtocol {
        Section(
                id: "error",
                rows: [
                    Row<ErrorCell>(
                            id: "error",
                            dynamicHeight: { [weak self] _ in
                                100 // todo: calculate height in ErrorCell
                            },
                            bind: { cell, _ in
                                cell.errorText = text
                            }
                    )
                ]
        )
    }

}

extension CoinPageViewController: SectionsDataSource {

    public func buildSections() -> [SectionProtocol] {
        var sections = [SectionProtocol]()

        sections.append(subtitleSection)
        sections.append(chartSection)

        switch state {
        case .loading:
            sections.append(spinnerSection)

        case .loaded(let viewItem):
            sections.append(returnOfInvestmentsSection(viewItems: viewItem.returnOfInvestmentsViewItems))

            if let marketInfoSection = marketInfoSection(marketInfo: viewItem.marketInfo) {
                sections.append(marketInfoSection)
            }

            if let marketsSection = marketsSection(fundCategories: viewItem.fundCategories, tickers: viewItem.tickers) {
                sections.append(marketsSection)
            }

            if !viewItem.description.isEmpty {
                sections.append(descriptionSection(description: viewItem.description))
            }

            if let categoriesSection = categoriesSection(categories: viewItem.categories, contractInfo: viewItem.contractInfo) {
                sections.append(categoriesSection)
            }

            if viewItem.guideUrl != nil || !viewItem.links.isEmpty {
                sections.append(linksSection(guideUrl: viewItem.guideUrl, links: viewItem.links))
            }

            sections.append(poweredBySection(text: "Powered by CoinGecko API"))

        case .failed(let error):
            sections.append(errorSection(text: error))
        }

        return sections
    }

}