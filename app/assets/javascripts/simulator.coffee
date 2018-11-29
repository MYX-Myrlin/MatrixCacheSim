###############################################################################
#
#   Constants
#
###############################################################################

# Size of each data element used by the simulator
integerSize = 4

###############################################################################
#
#   Data Classes
#
###############################################################################

# "Struct" used to store matrix data in
class Matrix
  # Initializes the matrix's data
  # @param x Width of the matrix
  # @param y Height of the matrix
  # @param address Starting byte address of the matrix
  # @param elements Array of DOM elements (via JQuery) that belong
  #   to the matrix. Must be in ascending order from index 0
  constructor: (@x, @y, @address, @elements) ->

  # Returns the value at the given position
  # This function will load the address into the cache if it is not already
  #   in the cache.
  get: (x, y) ->
    offset = y * @x + x
    return Cache.get(@address + (offset * integerSize))

  # Writes the value to the given position
  # This function will load the address into the cache if it is not already
  #   in the cache.
  set: (x, y, value) ->
    offset = y * @x + x
    Cache.set(@address + (offset * integerSize), value)
    return

  # Returns the DOM element at the given address in the matrix
  getDOMElement: (address) ->
    index = (address - @address) / integerSize
    return @elements[index]

# Class used to manage a statistics element on the page
class StatisticsElement
  # Constructs the element and initializes it with the specified value
  # @param elementID String containing the html ID of the element. Should not
  #   be prefixed with '#'
  # @param value Initial value for the element
  constructor: (elementID, @value) ->
    @element = $("#" + elementID)
    @originalValue = @value
    @updateValue(@value)

  # Decrements the element's value by 1
  decrement: =>
    @updateValue(@value - 1)

  # Increments the element's value by 1
  increment: =>
    @updateValue(@value + 1)

  # Resets the element's value to the original value
  reset: =>
    @updateValue(@originalValue)

  # Updates the element's displayed value
  updateValue: (newValue) =>
    @value = newValue
    @element.text(newValue)
    return

###############################################################################
#
#   Singleton Classes
#
###############################################################################

# Class used to simulate a cache
class Cache
  # Array of CacheSet objects
  @sets: []
  # Associativity of the cache
  @associativity: 0
  # Block size of the cache, in bytes
  @blockSize: 0
  # Number of total cache lines in the cache
  @cacheLineCount: 0
  # Size of the cache in bytes
  @cacheSize: 0
  # Number of bits used for the index part of an address
  @indexBits: 0
  # Number of bits used for the offset part of the address
  @offsetBits: 0
  # Number of sets in the cache
  @setCount: 0
  # Mask used to retrieve only the set index bits
  @setMask: 0
  # Constructs the cache
  # @param cacheSize Specifies the overall size of the cache, in bytes
  # @param associativity Specifies the associativity of the cache
  # @param blockSize Specifies the block size of the cache, in bytes
  @initialize: (cacheSize, associativity, blockSize) ->
    @cacheSize = cacheSize
    @associativity = associativity
    @blockSize = blockSize
    # Number of offset bits
    @offsetBits = Math.log2(@blockSize)
    # Number of cache lines in the cache
    @cacheLineCount = @cacheSize / @blockSize
    # Number of sets in the cache
    @setCount = @cacheLineCount / @associativity
    # Number of index bits
    @indexBits = Math.log2(@setCount)
    # Mask for getting the set that an address is in
    @setMask = ~0 << @indexBits
    @setMask = ~@setMask << @offsetBits
    # Initialize the sets
    for [0...@setCount]
      @sets.push(new CacheSet(@associativity))

  # Calculates the index of the set that the address belongs to
  @calcSet: (address) =>
    return (address & @setMask) >> @offsetBits

  # Clears all data from the cache
  @flush: =>
    @sets = []
    @initialize(@cacheSize, @associativity, @blockSize)

  # Gets the value at the given address. This function will load a cache
  #   line into the cache if the address is not already located in the
  #   cache.
  # @param address Address to load. May be any integer.
  @get: (address) =>
    # Get the set that the address should be in
    setIndex = @calcSet(address)
    # Track whether the address had to be loaded
    wasLoaded = false
    # If the address is not loaded, load it
    if !@sets[setIndex].inSet(address)
      # Get the data from memory
      data = Memory.getLine(address, @blockSize)
      # Calculate the address of the first byte of the returned cache line
      startAddress =
        Memory.calcCacheAlignmentBoundary(address, @blockSize)
      # Add the data to the correct set
      @sets[setIndex].load(startAddress, data)
      wasLoaded = true
    # Return the data at the given element
    return @sets[setIndex].get(address, wasLoaded)

  # Sets an integer to a specific value. If the address is not in cache,
  #   the cache line containing the address will be loaded into the cache.
  # @param address Address of the integer. Must be a multiple of 4.
  # @param value Value to set the integer to.
  @set: (address, value) =>
    # Get the set that the address should be in
    setIndex = @calcSet(address)
    # Track whether the address had to be loaded
    wasLoaded = false
    # If the address is not loaded, load it
    if !@sets[setIndex].inSet(address)
      # Get the data from memory
      data = Memory.getLine(address, @blockSize)
      # Calculate the address of the first byte of the returned cache line
      startAddress =
        Memory.calcCacheAlignmentBoundary(address, @blockSize)
      # Add the data to the correct set
      @sets[setIndex].load(startAddress, data)
      wasLoaded = true
    # Set the value
    @sets[setIndex].set(address, value, wasLoaded)
    return

# Class used to track the current simulation time. This class assumes that
#   any calls to getTime() are for storing the time, and therefore increments
#   the current time by 1 each time it is called. This is to ensure that the
#   same time is not returned twice.
class Clock
  # Stores the current time
  @time: 0
  constructor: ->
  # Returns the current time and increments it
  @getTime: () =>
    @time += 1

# Class used to simulate main memory
# For the purposes of this simulation, it is assumed that memory can only
#   store integers
class Memory
  @data: []

  # Allocates space for `size` integers. Will be aligned at a 16-byte boundary.
  # @returns This function returns the address of the first integer.
  @alloc: (size) =>
    # Check if padding is necessary
    if @data.length % integerSize != 0
      # Calculate how many integers need to be added to the array
      padding = @data.length % integerSize
      # Add the required padding
      for [0...padding]
        @data.push(0);
    # Create an array with the specified number of elements
    array = []
    for [0...size]
      array.push(0)
    # Calculate the address that will be returned
    returnAddress = @data.length * integerSize
    # Add the array to the data array
    @data = @data.concat(array)
    return returnAddress

  # Calculates the address of the first alignment boundary before the
  #   specified address.
  # @param address Address to calculate the alignment boundary
  # @param cacheLineSize Size, in bytes, of a cache line. Determines
  #   where alignment boundaries are.
  @calcCacheAlignmentBoundary: (address, cacheLineSize) ->
    return Math.floor(address / cacheLineSize) * cacheLineSize

  # Returns the value of a given integer
  # @param address Address of the integer. Must be a multiple of 4.
  @get: (address) =>
    # Calculate the index of the integer
    index = address / integerSize
    return @data[index]

  # Returns an array containing the requested address
  # @param address Address of the requested integer. Must be a multiple
  #   of 4.
  # @param lineSize Size, in bytes, of the cache line to retrieve
  @getLine: (address, lineSize) =>
    # Calculate the number of elements to return
    elementCount = lineSize / integerSize
    # Calculate the array index of the requested element
    index = address / integerSize
    # Calculate the index of the first element in the cache line to return
    startIndex = Math.floor(index / elementCount)
    # Return the data
    return @data.slice(startIndex, startIndex + elementCount)

  # Sets an integer to a specific value
  # @param address Address of the integer. Must be a multiple of 4.
  # @param value Value to set the integer to.
  @set: (address, value) =>
    # Calculate the index of the integer
    index = address / integerSize
    @data[index] = value
    return

# Class used to facilitate changes to the simulation page
class Model
  # Matrix object for Matrix A
  @matrixA: null
  # Matrix object for Matrix B
  @matrixB: null

  # Applies an effect to the specified element
  # @param action EAction value. Specifies what sort of visual effect to
  #   use.
  # @param matrixID EMatrix value. Specifies the matrix to apply the effect to.
  # @param address Byte address of the element to apply the effect to
  @applyAction: (action, matrixID, address) =>
    # Get a reference to the matrix
    matrix = if matrixID == EMatrix.MatrixA then @matrixA else @matrixB
    # Get a reference to the element to update
    element = matrix.getDOMElement(address)
    element.removeAttr('style')
    # Apply the correct effect to the element
    switch action
      when EAction.Loaded then element.css("background-color", "green")
      when EAction.Accessed then element.css("background-color", "black")
      when EAction.Evicted then element.css("background-color", "red")
    return

  # Searches for and adds references to the elements in each matrix
  # @param matrixX Specifies the width of matrix A. This value will be swapped
  #   with the specified height of matrix A when calculating the size of
  #   Matrix B.
  # @param matrixY Specifies the height of matrix A. This value will be swapped
  #   with the specified width of matrix A when calculating the size of
  #   Matrix B.
  @initialize: (matrixX, matrixY, matrixAAddress, matrixBAddress) =>
    # Construct each matrix
    @matrixA = new Matrix(matrixX, matrixY, matrixAAddress, [])
    @matrixB = new Matrix(matrixY, matrixX, matrixBAddress, [])
    # Load each matrix's elements
    matrixAElements = $(".matrixA-element")
    for index in [0..matrixAElements.length]
      @matrixA.elements.push(matrixAElements.eq(index))

    matrixBElements = $(".matrixB-element")
    for index in [0..matrixBElements.length]
      @matrixB.elements.push(matrixBElements.eq(index))
    return

  @reset: =>
    # Remove any styles that have been applied via the Model class
    for element in @matrixA.elements
      element.removeAttr('style')
    for element in @matrixB.elements
      element.removeAttr('style')
    return

# Class used to handle the cache simulation
class Simulator
  # Array of actions to replay on the simulation page
  @data: []
  # Delay between updates, in milliseconds
  @delay: 50

  # Statistics Sidebar DOM Element references
  @cacheHits: null
  @cacheMisses: null
  @cacheLoads: null
  @cacheEvictions: null
  @cacheUsage: null
  @cacheSize: null
  @cachePercentage: null
  @cacheVisualizerElements: []

  # Clears all saved actions
  @clear: =>
    @data = []
    @cacheHits.reset()
    @cacheMisses.reset()
    @cacheEvictions.reset()
    @cacheUsage.reset()
    @cacheSize.reset()
    @cachePercentage.reset()
    @updateCacheVisualization()

  @initialize: =>
    @cacheHits = new StatisticsElement("cache-hits", 0)
    @cacheMisses = new StatisticsElement("cache-misses", 0)
    @cacheEvictions = new StatisticsElement("cache-evictions", 0)
    @cacheUsage = new StatisticsElement("cache-usage", 0)
    @cacheSize = new StatisticsElement("cache-size", Cache.cacheLineCount)
    @cachePercentage = new StatisticsElement("cache-percentage", 0)
    cacheStatusElements = $(".cache-line-status")
    for i in [0...cacheStatusElements.length]
      @cacheVisualizerElements.push(cacheStatusElements.eq(i))

  # Adds an action to the simulation log
  # @param action Action object to store
  @logAction: (action) =>
    @data.push(action)

  # Runs through all saved actions and updates the simulation with their
  #   effects
  @simulate: =>
    # Executes an action
    run = (index) =>
      @data[index].run()
      @updateCacheVisualization()
      setTimeout((() -> finish(index)), @delay)
      return
    # Completes an action
    finish = (index) =>
      @data[index].finish()
      # If additional elements remain, call `run()` on the next element
      if index + 1 < @data.length
        setTimeout((() -> run(index + 1)), @delay)
      return
    setTimeout((() => run(0)), @delay)

  # Updates the cache usage percentage displayed on the page
  @updateCacheUsagePercentage: =>
    @cachePercentage.updateValue(@cacheUsage.value / @cacheSize.value * 100)

  # Updates the cache visualization
  @updateCacheVisualization: =>
    # Iterate over each cache set and update the visualization
    index = 0
    for set in Cache.sets
      color = "#dc3545" # Bootstrap default red
      if set.blocks[0].isValid()
        color = "#28a745" # Bootstrap default green
      @cacheVisualizerElements[index].css("background-color", color)
      ++index

###############################################################################
#
#   Enums
#
###############################################################################

# Enum used to identify what kind of action occurred (determines the visual
#   effect applied to an element on the page)
class EAction
  # Enum value used to indicate an element was loaded into cache
  @Loaded: 0
  # Enum value used to indicate an element was read from or written to
  @Accessed: 1
  # Enum value used to indicate an element was evicted from the cache
  @Evicted: 2
  # Enum value used to indicate that all effects should be cleared from
  #   the element
  @Clear: 3

# Enum used to identify the matrix to apply an action to
class EMatrix
  @MatrixA: 0
  @MatrixB: 1

###############################################################################
#
#   Action Classes
#
###############################################################################

# Class used to represent an action
class Action
  # Takes an address and calculates the matrix that the action applied to
  constructor: (@address) ->
    # If the address is before the first byte of matrix B, the address belongs
    #   to matrix A
    @matrix = if (@address < Model.matrixB.address) then EMatrix.MatrixA else EMatrix.MatrixB
  # Function to be overloaded by child classes. Applies the action to the
  #   simulation page elements
  run: =>
  # Function to be overloaded by child classes. Called to "complete" the
  #   action.
  finish: =>

class AccessElement extends Action
  # Constructs the access element action object
  # @param address Address of the element that was accessed
  # @param hit Specifies whether a cache hit occurred
  constructor: (address, @hit) ->
    super(address)
  run: =>
    Model.applyAction(EAction.Accessed, @matrix, @address)
    if @hit then Simulator.cacheHits.increment() else Simulator.cacheMisses.increment()
    return
  finish: =>
    Model.applyAction(EAction.Loaded, @matrix, @address)
    return

class LineLoad extends Action
  # Specifies the line loaded
  # @param matrix EMatrix value. Specifies the matrix whose element was
  #   accessed
  # @param address Byte address of the first element
  # @param count Number of elements in the line
  constructor: (address, @count) ->
    super(address)
  run: =>
    for offset in [0...@count * integerSize] by integerSize
      Model.applyAction(EAction.Loaded, @matrix, @address + offset)
    Simulator.cacheUsage.increment()
    Simulator.updateCacheUsagePercentage()
    return
  finish: =>
    # Nothing to do

class LineEviction extends Action
  # Specifies the line loaded
  # @param address Byte address of the first element
  # @param count Number of elements in the line
  constructor: (address, @count) ->
    super(address)
  run: =>
    for offset in [0...@count * integerSize] by integerSize
      Model.applyAction(EAction.Evicted, @matrix, @address + offset)
    Simulator.cacheEvictions.increment()
    Simulator.cacheUsage.decrement()
    Simulator.updateCacheUsagePercentage()
    return
  finish: =>
    for offset in [0...@count * integerSize] by integerSize
      Model.applyAction(EAction.Clear, @matrix, @address + offset)
    return

###############################################################################
#
#   Cache Classes
#
###############################################################################

# Class used to represent a cache line
class CacheLine
  # Creates the cache line with the specified information
  # @address Address of the first byte in the cache line.
  #   Should always be a multiple of 4.
  # @data Array containing the data in the cache. Should be
  #   an array of ints. Each element in the data array is
  #   assumed to be 4 bytes for purposes of calculating
  #   cache line size.
  constructor: ->
    # Address of the first byte in the cache
    @address = 0
    # Data array for the cache
    @data = []
    # Time at which the cache line was last used
    @lastUsed = 0
    # Size, in bytes, of the cache line
    @size = 0
    # Represents the valid bit for a cache line
    @valid = false

  # Returns the value of the integer at the given address.
  # @param address Address to retrieve the integer from. Must
  #   be a multiple of four.
  # @param wasLoaded Boolean indicating whether the element was just
  #   loaded into the cache.
  get: (address, wasLoaded) =>
    # Update the last accessed time
    @lastUsed = Clock.getTime()
    # Calculate the offset required to fetch the element
    offset = (address - @address) / integerSize
    # Log the data access
    Simulator.logAction(new AccessElement(address, !wasLoaded))
    return @data[offset]

  # Checks whether the cache line is valid
  isValid: () =>
    return @valid

  # Invalidates the cache line
  invalidate: () =>
    # Log the eviction
    Simulator.logAction(new LineEviction(@address, @data.length))
    # Clear the cache line's data
    @address = 0
    @data = []
    @lastUsed = 0
    @size = 0
    @valid = false
    return

  # Returns true if the address is located within the cache
  #   line. Returns false if the address is not located within
  #   the cache line.
  # @param address Address to check. Should be an integer.
  inLine: (address) =>
    # For an address to be in the cache line, the line must be valid
    # and the address must be in the range of addresses held by the
    # cache line
    return @valid && @address <= address && address < @address + @size

  # Loads the data into the cache line
  # @param address Address of the first byte of the cache line
  # @param data Array of integers representing the cache line
  load: (address, data) =>
    @address = address
    @data = data
    # Update the time the cache line was used
    @lastUsed = Clock.getTime()
    # Since each element in the data array is 4 bytes, the
    # overall size of the cache line is the data array's
    # length times 4 bytes.
    @size = @data.length * integerSize
    @valid = true
    # Log the load
    Simulator.logAction(new LineLoad(@address, @data.length))
    return

  # Sets the value of an integer. The address passed to this function
  #   must be a multiple of 4 and must be an address located within
  #   this cache line.
  # @param wasLoaded Boolean indicating whether the element was just
  #   loaded into the cache.
  set: (address, value, wasLoaded) =>
    # Update the last accessed time
    @lastUsed = Clock.getTime()
    # Calculate the offset required to fetch the element
    offset = (address - @address) / integerSize
    # Write the data to the cache line
    @data[offset] = value
    # Also write the data to main memory
    Memory.set(address, value)
    # Log the data write
    Simulator.logAction(new AccessElement(address, !wasLoaded))
    return

# Class used to represent a set of cache lines
class CacheSet
  # Initializes the cache set with the specified number of cache lines
  constructor: (setCount) ->
    # Array of cache lines in the set
    @blocks = []
    for [0...setCount]
      @blocks.push(new CacheLine())

  # Returns the value at the given address
  # @param address Address of the element to access
  # @param wasLoaded Boolean indicating whether the element was just
  #   loaded into the cache
  get: (address, wasLoaded) =>
    # Locate the block with the address
    for block in @blocks
      # If the block is invalid, ignore it
      if !block.isValid()
        continue
      # If the address is in the block, return the value
      #   at the address
      if block.inLine(address)
        return block.get(address, wasLoaded)
    return null

  # Checks whether the address is present in the set
  inSet: (address) =>
    # Check whether the address is in any block in the set
    for block in @blocks
      # If the block is invalid, ignore it
      if !block.isValid()
        continue
      # If the address is in the block, return true
      if block.inLine(address)
        return true
    # If this point is reached, all blocks were checked and
    # the address was not found in any of them
    return false

  # Loads a new cache line into the set, evicting a cache line
  #   if necessary
  load: (address, data) =>
    # Iterate over all loaded blocks and search for an invalid
    # cache line (in case a slot is available). Also track the
    # lowest last used time for all caches currently in the cache
    # (in case the set is full and a line needs to be evicted)

    # Tracks the least recently used cache
    lruCache = @blocks[0]
    for block in @blocks
      # Check whether the current block can be used for the cache
      # line
      if !block.isValid()
        block.load(address, data)
        # Since the data has been loaded, no additional work needs
        # to be done
        return
      # Check whether the current block should replace the last
      # recently used block
      if (lruCache.lastUsed < block.lastUsed)
        lruCache = block
    # If this point is reached, a cache line must be evicted
    lruCache.invalidate()
    lruCache.load(address, data)
    return

  # Sets the value of an integer.
  # @param address Address of the integer to set. This address must be
  #   a multiple of 4 and must be an address located within this cache set.
  # @param value Value to set the integer to
  # @param wasLoaded Boolean indicating whether the element was just
  #   loaded into the cache
  set: (address, value, wasLoaded) =>
    # Locate the block with the address
    for block in @blocks
      # If the block is invalid, ignore it
      if !block.isValid()
        continue
      # If the address is in the block, write the value to the block
      if block.inLine(address)
        block.set(address, value, wasLoaded)
        return
    return

###############################################################################
#
#   Transpose Algorithms
#
###############################################################################

# Basic, element by element transpose function
naive = =>
  for m in [0...Model.matrixA.y]
    for n in [0...Model.matrixA.x]
      Model.matrixB.set(m, n, Model.matrixA.get(n, m))
  return

# Blocked transpose function
# @param blockSize Size of each block, in number of ints
naiveBlocked = (blockSize) =>
  M = Model.matrixA.y
  N = Model.matrixB.x

  for i in [0...M] by blockSize
    for j in [0...N] by blockSize
      sizeM = if M - i > blockSize then blockSize else M - i
      sizeN = if N - j > blockSize then blockSize else N - j
      for m in [i...i + sizeM]
        for n in [j...j + sizeN]
          Model.matrixB.set(m, n, Model.matrixA.get(n, m))
  return

# Deferred write blocked transpose function
# @param blockSize Size of each block, in number of ints
deferredBlocked = (blockSize) =>
  M = Model.matrixA.y
  N = Model.matrixB.x

  for i in [0...M] by blockSize
    for j in [0...N] by blockSize
      sizeM = if M - i > blockSize then blockSize else M - i
      sizeN = if N - j > blockSize then blockSize else N - j
      for m in [i...i + sizeM]
        deferred = null
        for n in [j...j + sizeN]
          if (m == n)
            deferred = Model.matrixA.get(n, m)
          else
            Model.matrixB.set(m, n, Model.matrixA.get(n, m))
        if deferred?
          console.log("Deferred write")
          Model.matrixB.set(m, m, deferred)
  return

###############################################################################
#
#   Event Handlers
#
###############################################################################

reset = ->
  Cache.flush()
  Model.reset()
  Simulator.clear()
  return

###############################################################################
#
#   Initialization
#
###############################################################################

$ =>
  # Reset button event handler
  $("#reset-btn").click(reset)

  # Naive algorithm event handler
  $("#naive-btn").click ->
    reset()
    Simulator.clear()
    naive()
    Simulator.simulate()
    return

  # Naive blocked algorithm event handler (block size = 4)
  $("#naive-blocked-4-btn").click ->
    reset()
    Simulator.clear()
    naiveBlocked(4)
    Simulator.simulate()
    return

  # Naive blocked algorithm event handler (block size = 8)
  $("#naive-blocked-8-btn").click ->
    reset()
    Simulator.clear()
    naiveBlocked(8)
    Simulator.simulate()
    return

  # Deferred write algorithm event handler (block size = 4)
  $("#deferred-blocked-4-btn").click ->
    reset()
    Simulator.clear()
    deferredBlocked(4)
    Simulator.simulate()
    return

  # Deferred write algorithm event handler (block size = 8)
  $("#deferred-blocked-8-btn").click ->
    reset()
    Simulator.clear()
    deferredBlocked(8)
    Simulator.simulate()
    return

  matrixAAddress = Memory.alloc(32 * 32)
  matrixBAddress = Memory.alloc(32 * 32)
  Model.initialize(32, 32, matrixAAddress, matrixBAddress)
  Cache.initialize(1024, 1, 32)
  Simulator.initialize()
  ###
  Cache.get(0)
  Cache.get(32)
  Cache.get(0)
  Cache.get(matrixBAddress)
  Simulator.simulate()
  ###
