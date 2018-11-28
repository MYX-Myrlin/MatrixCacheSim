###############################################################################
#
#   Constants
#
###############################################################################

# Size of each data element used by the simulator
integerSize = 4

###############################################################################
#
#   Singleton Classes
#
###############################################################################

# Class used to track the current simulation time. This class assumes that
#   any calls to getTime() are for storing the time, and therefore increments
#   the current time by 1 each time it is called. This is to ensure that the
#   same time is not returned twice.
class Clock
  # Stores the current time
  @time: 0
  constructor: ->
  # Returns the current time and increments it
  @getTime: () ->
    @time += 1

# Class used to simulate main memory
# For the purposes of this simulation, it is assumed that memory can only
#   store integers
class Memory
  @data: []

  # Allocates space for `size` integers. Will be aligned at a 16-byte boundary.
  # @returns This function returns the address of the first integer.
  @alloc: (size) ->
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
    @data.concat(array)
    return returnAddress

  # Returns the value of a given integer
  # @param address Address of the integer. Must be a multiple of 4.
  @get: (address) ->
    # Calculate the index of the integer
    index = address / integerSize
    return @data[index]

  # Returns an array containing the requested address
  # @param address Address of the requested integer. Must be a multiple
  #   of 4.
  # @param lineSize Size, in bytes, of the cache line to retrieve
  @getLine: (address, lineSize) ->
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
  @set: (address, value) ->
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
  @applyAction: (action, matrixID, address) ->
    # Get a reference to the matrix
    matrix = (matrixID == EMatrix.MatrixA) ? matrixA : matrixB
    # Get a reference to the element to update
    element = matrix.get(address)
    element.removeAttr('style')
    # Apply the correct effect to the element
    switch action
      when EAction.Loaded then element.css("background-color", "green")
      when EAction.Accessed then element.css("background-color", "black")
      when EAction.Unloaded then element.css("background-color", "red")
    return

  # Searches for and adds references to the elements in each matrix
  # @param matrixX Specifies the width of matrix A. This value will be swapped
  #   with the specified height of matrix A when calculating the size of
  #   Matrix B.
  # @param matrixY Specifies the height of matrix A. This value will be swapped
  #   with the specified width of matrix A when calculating the size of
  #   Matrix B.
  @initialize: (matrixX, matrixY, matrixAAddress, matrixBAddress) ->
    # Store the size & address of each matrix
    @matrixA.x = matrixX
    @matrixA.y = matrixY
    @matrixA.address = matrixAAddress
    @matrixB.x = @matrixA.x
    @matrixB.y = @matrixA.y
    @matrixB.address = matrixBAddress
    # Load each matrix's elements
    loadElements(@matrixA.elements, $("#matrixA"))
    loadElements(@matrixB.elements, $("#matrixB"))
    return

  # Loads the elements in the matrices into the arrays
  @loadElements: (matrixArray, matrix) ->
    # Process each row
    for row in matrix.children(".div")
      @processRow(matrixArray, row)
    return

  # Loads all elements in the row to the matrix's array
  @processRow: (matrixArray, row) ->
    # Get all children of the row
    for element in row.children()
      matrixArray.push(element)
    return

  @reset: ->
    # Remove any styles that have been applied via the Model class
    for element in matrixAElements
      element.removeAttr('style')
    for element in matrixBElements
      element.removeAttr('style')
    return

# Class used to handle the cache simulation
class Simulator
  # Array of actions to replay on the simulation page
  @data: []
  # Delay between updates, in milliseconds
  @delay: 250

  # Clears all saved actions
  @clear: ->
    @data = []

  # Adds an action to the simulation log
  # @param action Action object to store
  @logAction: (action) ->
    @data.push(action)

  # Runs through all saved actions and updates the simulation with their
  #   effects
  @simulate: ->
    # Executes an action
    run = (index) ->
      @data[index].run()
      setTimeout((() -> finish(index)), @delay)
      return
    # Completes an action
    finish = (index) ->
      @data[index].finish()
      # If additional elements remain, call `run()` on the next element
      if (index + 1 == @data.length)
        setTimeout((() -> run(index + 1)), @delay)
      return

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

  # Returns the element at the given address in the matrix
  get: (address) ->
    index = (address - @address) / integerSize
    return @elements[index]

###############################################################################
#
#   Action Classes
#
###############################################################################

# Class used to represent an action
class Action
  # Takes an address and calculates the matrix that the action applied to
  constructor(@address) ->
    # If the address is before the first byte of matrix B, the address belongs
    #   to matrix A
    @matrix = if (@address < Model.matrixB.address) then EMatrix.MatrixA else EMatrix.MatrixB
  # Function to be overloaded by child classes. Applies the action to the
  #   simulation page elements
  run: ->
  # Function to be overloaded by child classes. Called to "complete" the
  #   action.
  finish: ->

class AccessElement extends Action
  constructor: (address) ->
    super(address)
  run: ->
    Model.applyAction(EAction.Accessed, @matrix, @address)
    return
  finish: ->
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
  run: ->
    for offset in [0...@count * integerSize] by integerSize
      Model.applyAction(EAction.Loaded, @matrix, @address + offset)
    return
  finish: ->
    # Nothing to do

class LineEviction extends Action
  # Specifies the line loaded
  # @param address Byte address of the first element
  # @param count Number of elements in the line
  constructor: (address, @count) ->
    super(address)
  run: ->
    for offset in [0...@count * integerSize] by integerSize
      Model.applyAction(EAction.Evicted, @matrix, @address + offset)
    return
  finish: ->
    # Nothing to do

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
  get: (address) ->
    # Update the last accessed time
    @lastUsed = Clock.getTime()
    # Calculate the offset required to fetch the element
    offset = (address - @address) / integerSize
    # Log the data access
    Simulator.logAction(new AccessElement(address))
    return @data[offset]

  # Checks whether the cache line is valid
  isValid: () ->
    return @valid

  # Invalidates the cache line
  invalidate: () ->
    # Log the eviction
    Simulator.logAction(new LineEviction(address, data.length))
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
  inLine: (address) ->
    # For an address to be in the cache line, the line must be valid
    # and the address must be in the range of addresses held by the
    # cache line
    return @valid && @address <= address && address < @address + @size

  # Loads the data into the cache line
  # @param address Address of the first byte of the cache line
  # @param data Array of integers representing the cache line
  load: (address, data) ->
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
    Simulator.logAction(new LineLoad(address, data.length))
    return

  # Sets the value of an integer. The address passed to this function
  #   must be a multiple of 4 and must be an address located within
  #   this cache line.
  set: (address, value) ->
    # Update the last accessed time
    @lastUsed = Clock.getTime()
    # Calculate the offset required to fetch the element
    offset = (address - @address) / integerSize
    # Write the data to the cache line
    @data[offset] = value
    # Also write the data to main memory
    Memory.set(address, value)
    # Log the data write
    Simulator.logAction(new AccessElement(address))
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
  get: (address) ->
    # Locate the block with the address
    for block in blocks
      # If the block is invalid, ignore it
      if !block.isValid()
        continue
      # If the address is in the block, return the value
      #   at the address
      if block.inLine(address)
        return block.get(address)
    return null

  # Checks whether the address is present in the set
  inSet: (address) ->
    # Check whether the address is in any block in the set
    for block in blocks
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
  load: (address, data) ->
    # Iterate over all loaded blocks and search for an invalid
    # cache line (in case a slot is available). Also track the
    # lowest last used time for all caches currently in the cache
    # (in case the set is full and a line needs to be evicted)

    # Tracks the least recently used cache
    lruCache = blocks[0]
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
  # @param value Value to set the integer to.
  set: (address, value) ->
    # Locate the block with the address
    for block in blocks
      # If the block is invalid, ignore it
      if !block.isValid()
        continue
      # If the address is in the block, write the value to the block
      if block.inLine(address)
        block.set(address, value)
        return
    return

# Class used to simulate a cache
class Cache
  # Constructs the cache
  # @param cacheSize Specifies the overall size of the cache, in bytes
  # @param associativity Specifies the associativity of the cache
  # @param blockSize Specifies the block size of the cache, in bytes
  constructor: (@cacheSize, @associativity, @blockSize) ->
    # Tracks the sets in the cache
    @sets = []
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

  # Calculates the index of the set that the address belongs to
  calcSet: (address) ->
    return (address & @setMask) >> @offsetBits

  # Gets the value at the given address. This function will load a cache
  #   line into the cache if the address is not already located in the
  #   cache.
  # @param address Address to load. May be any integer.
  get: (address) ->
    # Get the set that the address should be in
    setIndex = calcSet(address)
    # If the address is not loaded, load it
    if !@sets[setIndex].inSet(address)
      # Get the data from memory
      data = Memory.getLine(address)
      # Add the data to the correct set
      @sets[setIndex].load(address, data)
    # Return the data at the given element
    return @sets[setIndex].get(address)

  # Sets an integer to a specific value. If the address is not in cache,
  #   the cache line containing the address will be loaded into the cache.
  # @param address Address of the integer. Must be a multiple of 4.
  # @param value Value to set the integer to.
  set: (address, value) ->
    # Get the set that the address should be in
    setIndex = calcSet(address)
    # If the address is not loaded, load it
    if !@sets[setIndex].inSet(address)
      # Get the data from memory
      data = Memory.getLine(address)
      # Add the data to the correct set
      @sets[setIndex].load(address, data)
    # Set the value
    @sets[setIndex].set(address, value)
    return

###############################################################################
#
#   Transpose Algorithms
#
###############################################################################



###############################################################################
#
#   Event Handlers
#
###############################################################################



###############################################################################
#
#   Initialization
#
###############################################################################
