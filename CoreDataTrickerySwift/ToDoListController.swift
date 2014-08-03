//
//  ToDoListController.swift
//  CoreDataTrickerySwift
//
//  Created by Alek Astrom on 2014-07-30.
//  Copyright (c) 2014 Apps and Wonders. All rights reserved.
//

import CoreData

class ToDoListController: NSFetchedResultsControllerDelegate {
    
    var delegate: NSFetchedResultsControllerDelegate?
    
    var showsEmptySections: Bool = false {
    didSet {
        if showsEmptySections == oldValue { return }
        
        // Notify delegate that sections will be changed
        delegate?.controllerWillChangeContent?(toDosController)
        
        if showsEmptySections {
            generateSectionInfoWithEmptySections(true)
            notifyDelegateOfAddedEmptySections()
        } else {
            notifyDelegateOfRemovedEmptySections()
            generateSectionInfoWithEmptySections(false)
        }
        
        delegate?.controllerDidChangeContent?(toDosController)
    }
    }
    
    var sections: [ControllerSectionInfo] = []
    var oldSections: [ControllerSectionInfo] = []
    
    private lazy var toDosController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: ToDoMetaData.entityName())
        fetchRequest.relationshipKeyPathsForPrefetching = ["toDo"]
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sectionIdentifier", ascending: true),
            NSSortDescriptor(key: "internalOrder", ascending: false)]
        
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext, sectionNameKeyPath: "sectionIdentifier", cacheName: nil)
        
        controller.performFetch(nil)
        controller.delegate = self
        
        return controller
        }()
    
    private var managedObjectContext: NSManagedObjectContext
    private var listConfiguration: ToDoListConfiguration
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        self.listConfiguration = ToDoListConfiguration.defaultConfiguration(managedObjectContext)
        generateSectionInfoWithEmptySections(false)
    }
    
    func fetchedToDos() -> [ToDo] {
        let metaData = toDosController.fetchedObjects as [ToDoMetaData]
        return metaData.map {$0.toDo}
    }
    
    func toDoAtIndexPath(indexPath: NSIndexPath) -> ToDo {
        let sectionInfo = sections[indexPath.section]
        let metaData = toDosController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: sectionInfo.fetchedIndex!)) as ToDoMetaData
        return metaData.toDo
    }
    
    func reloadData() {
        toDosController.performFetch(nil)
        generateSectionInfoWithEmptySections(showsEmptySections)
    }
    
    //
    // Fetched results controller delegate
    //
    
    // Start by just forwarding all calls
    
    func controllerWillChangeContent(controller: NSFetchedResultsController!)  {
        oldSections = sections
        delegate?.controllerWillChangeContent?(controller)
    }
    
    func controller(controller: NSFetchedResultsController!, didChangeSection sectionInfo: NSFetchedResultsSectionInfo!, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType)  {
        
        // Regenerate all section info (I know this isn't Über-effective but it shouldn't take too much time)
        generateSectionInfoWithEmptySections(showsEmptySections)
        
        // If we show empty sections, fetched changes don't affect us
        if !showsEmptySections {
            delegate?.controller?(controller, didChangeSection: sectionInfo, atIndex: sectionIndex, forChangeType: type)
        }
    }
    
    func controller(controller: NSFetchedResultsController!, didChangeObject anObject: AnyObject!, atIndexPath indexPath: NSIndexPath!, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath!)  {
        
        var convertedOldIndexPath = realIndexPathForFetchedIndexPath(indexPath, sections: oldSections)
        var convertedNewIndexPath = realIndexPathForFetchedIndexPath(newIndexPath, sections: sections)
        
        let metaData = anObject as ToDoMetaData
        
        delegate?.controller?(controller, didChangeObject: metaData.toDo, atIndexPath: convertedOldIndexPath, forChangeType: type, newIndexPath: convertedNewIndexPath)
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController!)  {
        delegate?.controllerDidChangeContent?(controller)
    }
    
    //
    // Private methods
    //
    
    private func generateSectionInfoWithEmptySections(emptySections: Bool) {
        
        if emptySections {
            // Get all fetched sections
            let fetchedSections = (toDosController.sections as [NSFetchedResultsSectionInfo]).map {$0.name!}
            
            let configuration = ToDoListConfiguration.defaultConfiguration(managedObjectContext)
            // Map sections to sectionInfo structs with section and its fetched index
            sections = configuration.sectionsForCurrentConfiguration().map {
                ControllerSectionInfo(section: $0, fetchedIndex: find(fetchedSections, $0.toRaw()), fetchController: self.toDosController)
            }
            
        } else {
            // Just get all the sections from the fetched results controller
            sections = []
            for (fetchedIndex, sectionInfo) in enumerate(toDosController.sections as [NSFetchedResultsSectionInfo]) {
                let section = ToDoSection.fromRaw(sectionInfo.name!)!
                sections.append(ControllerSectionInfo(section: section, fetchedIndex: fetchedIndex, fetchController: self.toDosController))
            }
        }
    }
    
    private func notifyDelegateOfAddedEmptySections() {
        for (index, sectionInfo) in enumerate(sections) {
            if !sectionInfo.fetchedIndex {
                delegate?.controller?(toDosController, didChangeSection: nil, atIndex: index, forChangeType: .Insert)
            }
        }
    }
    
    private func notifyDelegateOfRemovedEmptySections() {
        for (index, sectionInfo) in enumerate(sections) {
            if !sectionInfo.fetchedIndex {
                delegate?.controller?(toDosController, didChangeSection: nil, atIndex: index, forChangeType: .Delete)
            }
        }
    }
    
    private func realIndexPathForFetchedIndexPath(fetchedIndexPath: NSIndexPath?, sections: [ControllerSectionInfo]) -> NSIndexPath? {
        if fetchedIndexPath {
            for (sectionIndex, sectionInfo) in enumerate(sections) {
                if sectionInfo.fetchedIndex == fetchedIndexPath!.section {
                    return NSIndexPath(forRow: fetchedIndexPath!.row, inSection: sectionIndex)
                }
            }
        }
        return nil
    }
}

class ControllerSectionInfo: NSFetchedResultsSectionInfo {
    let section: ToDoSection
    let fetchedIndex: Int?
    private let fetchController: NSFetchedResultsController
    
    init(section: ToDoSection, fetchedIndex: Int?, fetchController: NSFetchedResultsController) {
        self.section = section
        self.fetchedIndex = fetchedIndex
        self.fetchController = fetchController
    }
    
    var name: String! { return section.title() }
    var indexTitle: String! { return nil }
    var numberOfObjects: Int {
    if fetchedInfo { return fetchedInfo!.numberOfObjects }
    else { return 0 }
    }
    var objects: [AnyObject]! { return fetchedInfo?.objects }
    var fetchedInfo: NSFetchedResultsSectionInfo? {
    if fetchedIndex {
        return fetchController.sections[fetchedIndex!] as? NSFetchedResultsSectionInfo
    } else {
        return nil
        }
    }
}
