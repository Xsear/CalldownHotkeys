-- ListNode by: X-Tor
--------------------------------------------------------------

-- ListNode API --

ListNode = {}
ListNode.mt = { __index = ListNode }

function ListNode:new(data, prev, next)
    return setmetatable({
        data = data or nil,
        prev = prev or nil,
        next = next or nil
        }, ListNode.mt)
end

function ListNode:swapWith(iterator)
    if iterator then
        local tempData = self.data
        self.data = iterator.data
        iterator.data = tempData
    end
end

function ladvanceForward(list, node)
    if not node then -- node is nil, first iteration
        if list and list.head then
            return list.head, list.head.data
        end
    elseif node.next then
        return node.next, node.next.data
    end
end

function ladvanceBackward(list, node)
    if not node then -- node is nil, first iteration
        if list.tail then
            return list.tail, list.tail.data
        end
    elseif node.prev then
        return node.prev, node.prev.data
    end
end

List = {}
List.mt = { __index = List }

function List:new()
    return setmetatable({
        head = nil,
        tail = nil,
        count = 0
        }, List.mt)
end

function List:back()
    return self.head
end

function List:front()
    return self.tail
end

function List:size()
   return self.count 
end

function List:pushFront(data)
    if self.tail then -- not empty
        local newNode = ListNode:new(data, self.tail, nil)
        self.tail.next = newNode
        self.tail = newNode
    else
        local newNode = ListNode:new(data, nil, nil)
        self.head = newNode
        self.tail = newNode
    end
    
    self.count = self.count + 1
end

function List:pushBack(data)
    if self.tail then -- not empty
        local newNode = ListNode:new(data, nil, self.head)
        self.head.prev = newNode
        self.head = newNode
    else
        local newNode = ListNode:new(data, nil, nil)
        self.head = newNode
        self.tail = newNode
    end
    
    self.count = self.count + 1
end

function List:insert(iterator, data)
    if iterator then        
        newNode = ListNode:new(data, iterator.prev, iterator)
        
        if iterator.prev then
            iterator.prev.next = newNode
        else
            self.head = newNode
        end
        
        iterator.prev = newNode
        
        self.count = self.count + 1
        
        return newNode
    end
    
    return nil
end

function List:remove(iterator)
    if iterator then
        if iterator.prev then
            iterator.prev.next = iterator.next
        else
            self.head = iterator.next
        end
        
        if iterator.next then
            iterator.next.prev = iterator.prev
        else
            self.tail = iterator.prev
        end
        
        self.count = self.count - 1
        
        return iterator.next
    end
    
    return nil
end

function List:swapNodes(iterator1, iterator2)
    if iterator1 and iterator2 then
        if iterator1.prev == iterator2 then
            local tempEntry = iterator1
            iterator1 = iterator2
            iterator2 = tempEntry
        end
        
        if iterator1.next == iterator2 then
            if iterator1.prev then
                iterator1.prev.next = iterator2
            else
                self.head = iterator2
            end
            
            iterator2.prev = iterator1.prev
            
            iterator1.prev = iterator2
            iterator1.next = iterator2.next
            
            if iterator2.next then
                iterator2.next.prev = iterator1
            else
                self.tail = iterator1
            end
            
            iterator2.next = iterator1
        else
            if iterator1.prev then
                iterator1.prev.next = iterator2
            else
                self.head = iterator2
            end
            
            if iterator1.next then
                iterator1.next.prev = iterator2
            else
                self.tail = iterator2
            end
            
            if iterator2.prev then
                iterator2.prev.next = iterator1
            else
                self.head = iterator1
            end
            
            if iterator2.next then
                iterator2.next.prev = iterator1
            else
                self.tail = iterator1
            end
            
            local tempIterator = {}
            tempIterator.prev = iterator1.prev
            tempIterator.next = iterator1.next
            
            iterator1.prev = iterator2.prev
            iterator1.next = iterator2.next
            iterator2.prev = tempIterator.prev
            iterator2.next = tempIterator.next
        end
    end
end

function List:clear()
    while self.count > 0 do
        self:remove(self.head)
    end
end

function List:advance(iterator, distance)
    local ladvance = ladvanceForward
    if distance < 0 then
        distance = -distance
        ladvance = ladvanceBackward
    end
    
    while distance ~= 0 do
        iterator = ladvance(self, iterator)        
        distance = distance - 1
    end
    
    return iterator
end

function lnodes(list)
    return ladvanceForward, list, nil
end

function rlnodes(list)
    return ladvanceBackward, list, nil
end

--------------------------------------
---------- CALLDOWN EXAMPLE ----------
--------------------------------------

---------------------------------------------------------------------------
-- Inherits from ListNode and adds calldown-speicifc functionality to it --

CalldownEntry = {}
CalldownEntry.mt = { __index = CalldownEntry }

function CalldownEntry:new(data, prev, next, handlers)
    -- Simualates creation of visuals for the entry
    data.visuals = { MoveTo = function(index) print("Moved abilityId " .. data.abilityId .. " to index " .. index) end,
                     Remove = function() print("Removed abilityId " .. data.abilityId) end }
    
    local base = ListNode:new(data, prev or nil, next or nil)
    
    -- Create buttons
    base.upButton = FakeButton:Create()
    base.downButton = FakeButton:Create()
    base.removeButton = FakeButton:Create()
    
    -- Bind the buttons to the correct handlers
    base.upButton:Bind(function() handlers.upHandler(base) end)
    base.downButton:Bind(function() handlers.downHandler(base) end)
    base.removeButton:Bind(function() handlers.removeHandler(base) end)
    
    setmetatable(CalldownEntry, getmetatable(base))
    
    return setmetatable(base, CalldownEntry.mt)
end

-------------------------------------------------------------------
-- Inherits from List adds calldown-speicifc functionality to it --

CalldownGroup = {}
CalldownGroup.mt = { __index = CalldownGroup }

function CalldownGroup:new()       
    local base = List:new()
    
    setmetatable(CalldownGroup, getmetatable(base))
    
    return setmetatable(base, CalldownGroup.mt)
end

function CalldownGroup:pushFront(data)
    local handlers = { upHandler = function(iterator) self:handleUp(iterator) end,
                       downHandler = function(iterator) self:handleDown(iterator) end,
                       removeHandler = function(iterator) self:handleRemove(iterator) end }
    
    if self.tail then -- not empty
        local newCalldown = CalldownEntry:new(data, self.tail, nil, handlers)
        self.tail.next = newCalldown
        self.tail = newCalldown
    else
        local newCalldown = CalldownEntry:new(data, nil, nil, handlers)
        self.head = newCalldown
        self.tail = newCalldown
    end
    
    self.count = self.count + 1
end

function CalldownGroup:handleUp(iterator)
    local index = 1
    for curIterator, data in lnodes(self) do
        if curIterator == iterator then
            break
        end
        
        index = index + 1
    end
    
    local prevIterator = self:advance(iterator, -1)
    if prevIterator then
        self:swapNodes(iterator, prevIterator)
        iterator.data.visuals:MoveTo(index - 1)
        prevIterator.data.visuals:MoveTo(index)
    end
end

function CalldownGroup:handleDown(iterator)
    local index = 1
    for curIterator, data in lnodes(self) do
        if curIterator == iterator then break end
        
        index = index + 1
    end
    
    local nextIterator = self:advance(iterator, 1)
    if nextIterator then
        self:swapNodes(iterator, nextIterator)
        iterator.data.visuals:MoveTo(index + 1)
        nextIterator.data.visuals:MoveTo(index)
    end
end

function CalldownGroup:handleRemove(iterator)
    self:remove(iterator)
    iterator.data.visuals:Remove()
end

----------------------------------------------
----------- A pseudo button object -----------

FakeButton = {}
FakeButton.mt = { __index = FakeButton }

function FakeButton:Create()
    return setmetatable({}, FakeButton.mt)
end

function FakeButton:Bind(func)
    self.bindFunc = func
end

-- Simulates a press of a button
function FakeButton:Press()
    if self.bindFunc then
        self.bindFunc()
    end
end 