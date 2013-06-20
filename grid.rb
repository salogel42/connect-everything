# encoding: utf-8

require 'colorize'
require 'json'

class Cell
  attr_accessor :cables, :can_add

  DIRECTIONS = [:up, :right, :down, :left]
  def initialize opt
    @game = opt[:game] or raise ArgumentError
    @row = opt[:row] or raise ArgumentError
    @col = opt[:col] or raise ArgumentError
    @cables = {}
    @can_add = {}
    Cell.each_direction do |dir|
      @cables[dir] = false
    end
  end

  def self.each_direction
    DIRECTIONS.each {|dir| yield dir}
  end


  # the elementS in the arrays should be ordered started from :up
  # as returned from cable_dirs
  STRINGS = {
    [] => ' ',
    [:up]     => '╵',
    [:right]  => '╶',
    [:down]   => '╷',
    [:left]   => '╴',
    [:up, :right] => '└',
    [:right, :down] => '┌',
    [:down, :left] => '┐',
    [:up, :left] => '┘',
    [:up, :down] => '│',
    [:right, :left] => '─',
    [:up, :right, :down] => '├',
    [:right, :down, :left] => '┬',
    [:up, :down, :left] => '┤',
    [:up, :right, :left] => '┴',
    [:up, :right, :down, :left] => '┼'
  }

  def to_s
    STRINGS[cable_dirs] || '?'
  end

  # binary representation (as a string)
  def binary
    res = ''
    Cell.each_direction do |dir|
      res << (@cables[dir] ? '1' : '0')
    end
    res
  end

  # array of directions in which the cables go
  def cable_dirs
    @cables.keys.select{|d|@cables[d]}.sort_by {|dir| Cell.dir_to_num(dir)}
  end

  # from symbol description of a direction to numerical description
  def self.dir_to_num dir
    case dir
      when :up then 0
      when :right then 1
      when :down then 2
      when :left then 3
      else
        raise ArgumentError
    end
  end

  def self.num_to_dir num
    case num
      when 0 then :up
      when 1 then :right
      when 2 then :down
      when 3 then :left
      else
        raise ArgumentError
    end
  end

  def self.opposite dir
    case dir
      when :up then :down
      when :down then :up
      when :left then :right
      when :right then :left
      else
        raise ArgumentError
    end
  end

  def neighbor dir
    row, col = @row, @col
    case dir
      when :up then row -= 1
      when :down then row += 1
      when :left then col -= 1
      when :right then col += 1
      else
        raise ArgumentError
    end
    @game.cell_at(row, col)
  end

  def each_neighbor
    Cell.each_direction do |dir|
      n = neighbor(dir)
      yield n, dir if n
    end
  end


  ###
  ###  grid creation helpers
  ###

  def complete?
    @can_add.values.none?
  end

  def neighbors_cannot_connect
    each_neighbor do |n, dir|
      n.can_add[Cell.opposite dir] = false
    end
  end

  # returns the neighbor towards which the new cable connects
  def add_random_cable
    raise 'cannot add any more cables' if complete?
    # find a random direction
    valid_directions = DIRECTIONS.select{|dir| @can_add[dir]}
    dir = valid_directions[rand valid_directions.size]

    add_cable dir
  end

  def add_cable(dir)
    @cables[dir] = true
    @can_add[dir] = false
    n = neighbor(dir)
    n.cables[Cell.opposite(dir)] = true
    n.can_add[Cell.opposite(dir)] = false
    n.neighbors_cannot_connect
    n
  end
end



















class Grid
  LEVELS = [
      {
        rows: 2,
        cols: 3,
        time: 5 * 60
      },
      {
          rows: 3,
          cols: 4,
          time: 8 * 60
      },
      {
          rows: 4,
          cols: 6,
          time: 12 * 60
      },
      {
          rows: 6,
          cols: 9,
          time: 20 * 60
      },
      {
          rows: 9,
          cols: 13,
          time: 30 * 60
      },
      {
          rows: 2,
          cols: 3,
          time: 5 * 60,
          wrapping: true,
      },
      {
          rows: 3,
          cols: 4,
          time: 8 * 60,
          wrapping: true
      },
      {
          rows: 4,
          cols: 6,
          time: 12 * 60,
          wrapping: true
      },
      {
          rows: 6,
          cols: 9,
          time: 20 * 60,
          wrapping: true
      },
      {
          rows: 9,
          cols: 13,
          time: 30 * 60,
          wrapping: true
      }

  ]

  def initialize opt={}
    p opt
    level_info = level_info(opt[:level])
    @rows = level_info[:rows]
    @cols = level_info[:cols]
    @wrapping = level_info[:wrapping] == true
    @time = level_info[:time]
    create_cables
  end

  def level_info(level)
    LEVELS[level-1] || {rows: 9, cols: 13, wrapping: true, time: 30}
  end


  # game creation
  def create_empty_grid
    @cells = []
    @rows.times do |r|
      @cols.times do |c|
        @cells << Cell.new(game: self, row: r, col: c)
      end
    end
  end

  def create_cables
    create_empty_grid
    #@cells.each do |c|
    #  Cell.each_direction do |dir|
    #    c.cables[dir] = true if rand > 0.5
    #  end
    #end

    @cells.each do |cell|
      Cell.each_direction do |dir|
        cell.can_add[dir] = cell.neighbor(dir) != nil
      end
    end

    # random initial cell
    cell0 = @cells[rand @cells.size]
    cell0.neighbors_cannot_connect
    incomplete_cells = [cell0]
    empty_cells = @rows * @cols
    while empty_cells > 0 && incomplete_cells.length > 0 do
      cell = incomplete_cells[rand incomplete_cells.size]
      new_cell = cell.add_random_cable
      incomplete_cells << new_cell
      # remove completed cells
      incomplete_cells.select! {|c| !c.complete?}
      empty_cells -= 1
    end
  end

  def to_s
    res = ''
    @rows.times do |r|
      @cols.times do |c|
        cell = cell_at(r, c)
        s = cell.to_s
        s = s.on_red if cell.complete?
        res << s
      end
      res << "\n"
    end
    res
  end

  def serialize
    {cells: @cells.map(&:binary).join(','),
     rows: @rows,
     cols: @cols,
     time: @time,
     wrapping: @wrapping}.to_json
  end

  # 0 indexed
  def cell_at(row, col)
    if row < 0 || row >= @rows || col < 0 || col >= @cols
      if @wrapping
        row %= @rows
        col %= @cols
      else
        return nil
      end
    end
    @cells[row*@cols + col]
  end
end

