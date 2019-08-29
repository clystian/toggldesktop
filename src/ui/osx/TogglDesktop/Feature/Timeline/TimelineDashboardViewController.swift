//
//  TimelineDashboardViewController.swift
//  TogglDesktop
//
//  Created by Nghia Tran on 6/17/19.
//  Copyright © 2019 Alari. All rights reserved.
//

import Cocoa

protocol TimelineDashboardViewControllerDelegate: class {

    func timelineDidChangeDate(_ date: Date)
}

final class TimelineDashboardViewController: NSViewController {

    // MARK: OUTLET

    @IBOutlet weak var datePickerContainerView: NSView!
    @IBOutlet weak var recordSwitcher: OGSwitch!
    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var emptyLbl: NSTextField!
    @IBOutlet weak var emptyActivityLbl: NSTextField!
    @IBOutlet weak var emptyActivityLblPadding: NSLayoutConstraint!
    
    // MARK: Variables

    weak var delegate: TimelineDashboardViewControllerDelegate?
    private var selectedGUID: String?
    private var isFirstTime = true
    lazy var datePickerView: DatePickerView = DatePickerView.xibView()
    private lazy var datasource = TimelineDatasource(collectionView)
    private var zoomLevel: TimelineDatasource.ZoomLevel = .x1 {
        didSet {
            datasource.update(zoomLevel)
        }
    }
    private lazy var timeEntryHoverController: TimelineTimeEntryHoverViewController = {
        return TimelineTimeEntryHoverViewController(nibName: "TimelineTimeEntryHoverViewController", bundle: nil)
    }()
    private lazy var timeEntryHoverPopover: NSPopover = {
        let popover = NSPopover()
        popover.animates = false
        popover.behavior = .semitransient
        popover.contentViewController = timeEntryHoverController
        timeEntryHoverController.popover = popover
        return popover
    }()
    private lazy var activityHoverController: TimelineActivityHoverController = {
        return TimelineActivityHoverController(nibName: "TimelineActivityHoverController", bundle: nil)
    }()
    private lazy var activityHoverPopover: NSPopover = {
        let popover = NSPopover()
        popover.animates = false
        popover.behavior = .semitransient
        popover.contentViewController = activityHoverController
        return popover
    }()
    private lazy var editorPopover: EditorPopover = {
        let popover = EditorPopover()
        popover.animates = false
        popover.behavior = .transient
        popover.prepareViewController()
        return popover
    }()

    // MARK: View
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initCommon()
        initNotifications()
        initCollectionView()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Scroll to the first visible item at the first time open Timeline
        if isFirstTime {
            isFirstTime = false
            datasource.scrollToVisibleItem()
        }
    }

    func updateNextKeyView() {
        recordSwitcher.nextKeyView = datePickerView.previousDateBtn
        datePickerView.updateNextKeyView()
    }

    func render(with cmd: TimelineDisplayCommand) {
        let timeline = TimelineData(cmd: cmd, zoomLevel: zoomLevel)
        let date = Date(timeIntervalSince1970: cmd.start)
        let shouldScroll = datePickerView.currentDate != date
        datePickerView.currentDate = date
        datasource.render(timeline)
        updatePositionOfEditorIfNeed()
        handleEmptyState(timeline)

        if shouldScroll {
            datasource.scrollToVisibleItem()
        }
    }
    
    @IBAction func recordSwitchOnChanged(_ sender: Any) {
        DesktopLibraryBridge.shared().enableTimelineRecord(recordSwitcher.isOn)
    }

    @IBAction func zoomLevelDecreaseOnChange(_ sender: Any) {
        guard let next = zoomLevel.nextLevel else { return }
        zoomLevel = next
    }

    @IBAction func zoomLevelIncreaseOnChange(_ sender: Any) {
        guard let previous = zoomLevel.previousLevel else { return }
        zoomLevel = previous
    }
}

// MARK: Private

extension TimelineDashboardViewController {

    fileprivate func initCommon() {
        datasource.delegate = self
        datePickerContainerView.addSubview(datePickerView)
        datePickerView.edgesToSuperView()
        datePickerView.delegate = self
        datePickerView.setBackgroundForTimeline()
        emptyActivityLbl.frameCenterRotation = -90
    }

    fileprivate func initNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.handleDisplaySettingNotification(_:)),
                                               name: NSNotification.Name(kDisplaySettings),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.reloadTimeline),
                                               name: Notification.Name(kDisplayTimeEntryList),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.didAddManualTimeNotification),
                                               name: NSNotification.Name.didAdddManualTime,
                                               object: nil)
    }

    fileprivate func initCollectionView() {

    }

    @objc private func handleDisplaySettingNotification(_ noti: Notification) {
        guard let cmd = noti.object as? DisplayCommand,
            let setting = cmd.settings else { return }
        recordSwitcher.setOn(isOn: setting.timeline_recording_enabled, animated: false)
        updateEmptyActivityText()
    }

    @objc private func reloadTimeline() {
        DesktopLibraryBridge.shared().timelineGetCurrentDate()
    }

    @objc private func didAddManualTimeNotification() {
        // Ignore if the Timeline controller is not showing
        guard view.window != nil else { return }

        // Switch to current date
        DesktopLibraryBridge.shared().timelineSetDate(Date())

        // Get the New item, which the lib just added
        guard let numberOfItem = datasource.timeline?.numberOfItems(in: TimelineData.Section.timeEntry.rawValue) else { return }
        let reversedCollection = (0..<numberOfItem).reversed()
        for index in reversedCollection {
            let indexPath = IndexPath(item: index, section: TimelineData.Section.timeEntry.rawValue)
            let itemView = collectionView.item(at: indexPath)

            // Present editor
            if let item = itemView as? TimelineTimeEntryCell {
                collectionView.scrollToItems(at: Set<IndexPath>(arrayLiteral: indexPath), scrollPosition: .centeredVertically)
                shouldPresentTimeEntryEditor(in: item.view, timeEntry: item.timeEntry.timeEntry)
                return
            }
        }
    }

    fileprivate func handleEmptyState(_ timeline: TimelineData) {
        emptyLbl.isHidden = !timeline.timeEntries.isEmpty
        emptyActivityLbl.isHidden = !timeline.activities.isEmpty
        updateEmptyActivityText()
    }

    private func updateEmptyActivityText() {
        emptyActivityLbl.stringValue = recordSwitcher.isOn ? "No activity was recorded yet..." : "Turn on activity\nrecording to see results."
        emptyActivityLblPadding.constant = recordSwitcher.isOn ? -40 : -50
    }
}

// MARK: DatePickerViewDelegate

extension TimelineDashboardViewController: DatePickerViewDelegate {

    func datePickerOnChanged(_ sender: DatePickerView, date: Date) {
        editorPopover.close()
        DesktopLibraryBridge.shared().timelineSetDate(date)
        delegate?.timelineDidChangeDate(date)
    }

    func datePickerShouldClose(_ sender: DatePickerView) {

    }

    func isTimeEntryRunning(_ sender: DatePickerView) -> Bool {
        return false
    }

    func shouldOpenCalendar(_ sender: DatePickerView) -> Bool {
        return true
    }

    func datePickerDidTapPreviousDate(_ sender: DatePickerView) {
        editorPopover.close()
        DesktopLibraryBridge.shared().timelineSetPreviousDate()
    }

    func datePickerDidTapNextDate(_ sender: DatePickerView) {
        editorPopover.close()
        DesktopLibraryBridge.shared().timelineSetNextDate()
    }
}

// MARK: TimelineDatasourceDelegate

extension TimelineDashboardViewController: TimelineDatasourceDelegate {

    func shouldPresentTimeEntryHover(in view: NSView, timeEntry: TimelineTimeEntry) {
        guard !editorPopover.isShown else { return }
        timeEntryHoverPopover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxX)
        timeEntryHoverController.render(with: timeEntry)
    }

    func shouldPresentActivityHover(in view: NSView, activity: TimelineActivity) {
        guard !editorPopover.isShown else { return }
        activityHoverPopover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxX)
        activityHoverController.render(activity)
    }

    func shouldDismissTimeEntryHover() {
        timeEntryHoverPopover.close()
    }

    func shouldDismissActivityHover() {
        activityHoverPopover.close()
    }

    func shouldPresentTimeEntryEditor(in view: NSView, timeEntry: TimeEntryViewItem) {
        shouldDismissTimeEntryHover()
        selectedGUID = timeEntry.guid
        editorPopover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxX)
        editorPopover.setTimeEntry(timeEntry)
    }

    func startNewTimeEntry(at started: TimeInterval, ended: TimeInterval) {
        guard let guid = DesktopLibraryBridge.shared().starNewTimeEntry(atStarted: started, ended: ended) else { return }
        self.showEditorForTimeEntry(with: guid)
    }

    fileprivate func showEditorForTimeEntry(with guid: String) {
        guard let timeEntries = datasource.timeline?.timeEntries else { return }

        // Get the index for item with guid
        let foundIndex = timeEntries.firstIndex(where: { entry -> Bool in
            if let timeEntry = entry as? TimelineTimeEntry,
                let timeEntryGUID = timeEntry.timeEntry.guid,
                timeEntryGUID == guid {
                return true
            }
            return false
        })

        // Get all essential data to present Editor
        guard let index = foundIndex else { return }
        let indexPath = IndexPath(item:index, section: TimelineData.Section.timeEntry.rawValue)
        guard let item = datasource.timeline?.item(at: indexPath) as? TimelineTimeEntry,
            let cell = collectionView.item(at: indexPath) else { return }
        shouldPresentTimeEntryEditor(in: cell.view, timeEntry: item.timeEntry)
    }

    fileprivate func updatePositionOfEditorIfNeed() {
        guard editorPopover.isShown,
            let selectedGUID = selectedGUID else { return }

        // Search the last index for GUID
        // Since everytime we change the Time entry data
        // New Entry will come from Library
        let index = datasource.timeline?.timeEntries.firstIndex(where: { (entry) -> Bool in
            if let timeEntry = entry as? TimelineTimeEntry {
                return timeEntry.timeEntry.guid == selectedGUID
            }
            return false
        })
        guard let item = index else {
            editorPopover.close()
            return
        }
        let indexPath = IndexPath(item: item, section: TimelineData.Section.timeEntry.rawValue)
        guard let cell = collectionView.item(at: indexPath) else {
            editorPopover.close()
            return
        }

        editorPopover.animates = false
        editorPopover.show(relativeTo: cell.view.bounds, of: cell.view, preferredEdge: .maxX)
    }
}