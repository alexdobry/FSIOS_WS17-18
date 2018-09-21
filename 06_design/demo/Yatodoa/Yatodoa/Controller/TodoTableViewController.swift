//
//  TodoTableViewController.swift
//  Done
//
//  Created by Alex on 26.10.17.
//  Copyright © 2017 Alexander Dobrynin. All rights reserved.
//

import UIKit

class TodoTableViewController: UITableViewController {
    
    private struct Storyboard {
        static let DetailSegueIdentifier = "TodoDetailSegue"
    }
    
    var todos: [ToDo] = [] {
        didSet {
            print(todos)
            
            todosSections = todos.groupBy(key: { todo in
                return ToDoType(todo: todo)
            }).sorted { (l, r) -> Bool in
                return l.key < r.key
            }
        }
    }
    
    var todosSections: [(key: ToDoType, value: [ToDo])] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    
        tableView.register(UINib(nibName: ToDoTableViewCell.NibName, bundle: nil), forCellReuseIdentifier: ToDoTableViewCell.ReuseIdentifier)
        tableView.register(UINib(nibName: AddItemTableViewCell.NibName, bundle: nil), forCellReuseIdentifier: AddItemTableViewCell.ReuseIdentifier)
        
        todos.append(ToDo.empty)
        
        populate(5)
    }
    
    private func populate(_ n: Int) {
        (0..<n).forEach { // populate data
            todos.append(ToDo(task: String($0)))
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return todosSections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return todosSections[section].value.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let (section, todos) = todosSections[indexPath.section]
        let todo = todos[indexPath.row]
        
        switch section {
        case .add:
            let cell = tableView.dequeueReusableCell(withIdentifier: AddItemTableViewCell.ReuseIdentifier, for: indexPath) as! AddItemTableViewCell
            cell.placeholder = "dein todo..."
            cell.delegate = self
            
            return cell
        case .open, .done:
            let cell = tableView.dequeueReusableCell(withIdentifier: ToDoTableViewCell.ReuseIdentifier, for: indexPath) as! ToDoTableViewCell
            cell.delegate = self
            cell.todo = todo.task
            cell.completed = todo.completed
            cell.favorized = todo.favorite
            
            cell.accessoryType = .detailDisclosureButton
            
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return todosSections[section].key.headerTitle
    }
    
    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let todo = todosSections[indexPath.section].value[indexPath.row]
        
        performSegue(withIdentifier: Storyboard.DetailSegueIdentifier, sender: todo)
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle { // FIXME: assignment
        switch todosSections[indexPath.section].key { // delete is only allowed on open todos
            case .add, .done: return .none
            case .open: return .delete
        }
    }
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch todosSections[indexPath.section].key {
        case .add, .done: return nil
        case .open:
            var todo = todosSections[indexPath.section].value[indexPath.row] // make it mutable
            let title = todo.favorite ? "Unfavorite" : "Favorite" // title is depending on state
            
            let fav = UIContextualAction(style: .normal, title: title, handler: { (_, _, completion) in
                // flip bool of todo's favorite property
                todo.favorite = !todo.favorite
                
                self.favorize(todo, withAnimation: true, atIndexPath: indexPath)
                
                // call completion
                completion(true)
            })
            
            fav.backgroundColor = UIColor.favoriteYellow
            
            let swipeActionConfig = UISwipeActionsConfiguration(actions: [fav])
            return swipeActionConfig
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {  // FIXME: assignment
        switch editingStyle {
        case .delete:
            let todo = todosSections[indexPath.section].value[indexPath.row]
            
            self.delete(todo, withAnimation: true, atIndexPath: indexPath)
        case .insert, .none: break
        }
    }
    
    // MARK: - navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else { return }
        
        switch identifier {
        case Storyboard.DetailSegueIdentifier:
            guard let dvc = segue.destination as? DetailTodoTableViewController else { return }
            
            dvc.delegate = self
            dvc.todo = sender as? ToDo
        default: break
        }
    }
    
    // MARK: - private helper
    
    private func indexPath(of todo: ToDo) -> IndexPath {
        return todosSections.first(where: { $0.value.contains(todo) }).map { IndexPath(row: $0.value.index(of: todo)!, section: $0.key.hashValue) }!
    }
    
    private func delete(_ todo: ToDo, withAnimation animation: Bool, atIndexPath path: IndexPath?) {
        let indexPath = path ?? self.indexPath(of: todo)
        let rows = tableView.numberOfRows(inSection: indexPath.section)

        let index = todos.index(of: todo)!
        todos.remove(at: index)
        
        if animation {
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic) // this line alone will crash when it is the last row of section. fix with lines below
            
            if (rows - 1) == 0 { // -1 because we are about to delete from right now
                tableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
            }
            
            tableView.endUpdates()
        } else {
            tableView.reloadData()
        }
    }
    
    private func favorize(_ todo: ToDo, withAnimation animation: Bool, atIndexPath path: IndexPath?) {
        let indexPath = path ?? self.indexPath(of: todo)
        let index = self.todos.index(of: todo)!
        
        if animation {
            // change model by inserting at 'position`
            let position = todo.favorite ? 1 : self.todosSections[indexPath.section].value.count
            // change model
            self.todos.remove(at: index) // change model
            self.todos.insert(todo, at: position)
            
            // change tableView's "model"
            let destination = IndexPath(row: position - 1, section: indexPath.section)
            tableView.moveRow(at: indexPath, to: destination) // animate changes
            
            // set color, because `moveRow` does not call `cellForRowAtIndexPath`
            (tableView.cellForRow(at: destination) as! ToDoTableViewCell).favorized = todo.favorite
        } else {
            todos[index] = todo
            tableView.reloadData()
        }
    }
    
    private func insert(_ todo: ToDo, animated: Bool) {
        if animated {
            let section = ToDoType.open
            let sectionsExists = todosSections.contains(where: { $0.key == section }) // before we append
            todos.append(todo)
            
            let nextPos = todosSections.first(where: { $0.key == section })!.value.count - 1 // after we append
            
            let indexPath = IndexPath(row: nextPos, section: section.hashValue)
            
            if sectionsExists {
                tableView.insertRows(at: [indexPath], with: .automatic)
            } else {
                tableView.beginUpdates()
                tableView.insertSections(IndexSet(integer: section.hashValue), with: .automatic)
                tableView.insertRows(at: [indexPath], with: .automatic)
                tableView.endUpdates()
            }
        } else {
            todos.append(todo)
            tableView.reloadData()
        }
    }
}

extension TodoTableViewController: ToDoTableViewCellDelegate {
    
    private func update(cell: ToDoTableViewCell, mutate: (inout ToDo) -> Void) {
        let indexPath = tableView.indexPath(for: cell)!
        var todo = todosSections[indexPath.section].value[indexPath.row] // make todo mutable
        let index = todos.index(of: todo)!
        
        mutate(&todo)
        
        todos[index] = todo
        tableView.reloadData()
    }
    
    func todoCell(_ cell: ToDoTableViewCell, wasCompleted completed: Bool) {
        update(cell: cell) { (todo: inout ToDo) in
            todo.completed = completed
            todo.favorite = false
        }
    }
    
    func todoCell(_ cell: ToDoTableViewCell, updatedTodo task: String) {
        update(cell: cell) { (todo: inout ToDo) in
            todo.task = task
        }
    }
}

extension TodoTableViewController: AddItemTableViewCellDelegate {
    
    func addItemCell(_ cell: AddItemTableViewCell, didCreateItem string: String?) {
        guard let string = string, !string.isEmpty else { return }
        
        insert(ToDo(task: string), animated: true)
    }
}

extension TodoTableViewController: DetailTodoTableViewControllerDelegate {
    
    func detailVC(_ viewController: DetailTodoTableViewController, returnsWithReason unwindReason: ReturnReason) {
        debugPrint(unwindReason)
        
        switch unwindReason {
        case .updated(let todo):
            let index = todos.index(of: todo)!
            todos[index] = todo
            
            tableView.reloadData()
        case .favorized(let todo):
            favorize(todo, withAnimation: true, atIndexPath: nil)
        case .deleted(let todo):
            delete(todo, withAnimation: true, atIndexPath: nil)
        }
    }
}
