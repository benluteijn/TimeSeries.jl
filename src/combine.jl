import Base: merge

###### merge ####################

function merge{T}(ta1::TimeArray{T}, ta2::TimeArray{T}; colnames = [""], method="inner")
    # first test metadata matches
    ta1.meta == ta2.meta ? meta = ta1.meta : error("metadata doesn't match")
    # find the smaller time array if it exists
    if  length(ta1) > length(ta2) 
        longer        = ta1 
        shorter       = ta2
        originalorder = true
    else
        longer        = ta2 
        shorter       = ta1
        originalorder = false
    end

    # interate to find when there is a match on timestamp
    counter = Int[]
    for i in 1:length(shorter)
        if in(shorter[i].timestamp[1], longer.timestamp)
            push!(counter, i)
        end
    end

    # create new shortened versions of ta1 and ta2
    newshorter  = shorter[counter]
    longermatch = longer[newshorter.timestamp]

    # concat the values columns
    originalorder ?
    vals = hcat(longermatch.values, newshorter.values) :
    vals = hcat(newshorter.values, longermatch.values)

    # get column names
    if length(colnames) < 2
    cnames = copy(ta1.colnames) # otherwise ta1 gets contaminated
      for m in 1:length(ta2.colnames)
        push!(cnames, ta2.colnames[m])
      end
     else cnames = colnames
     end

    TimeArray(newshorter.timestamp, vals, cnames, meta)
end

function merge1{T}(ta1::TimeArray{T}, ta2::TimeArray{T}; col_names=[""], method="inner")
    # start with array of Date
    tstamp = intersect(ta1.timestamp, ta2.timestamp)
    # get array of Ints
    tt1    = findin(ta1.timestamp, tstamp)
    tt2    = findin(ta2.timestamp, tstamp)
    # retrieve values that match the Int array matching dates
    vals1  = ta1[tt1].values
    vals2  = ta2[tt2].values
    # combine the values arrays
    vals   = hcat(vals1,vals2)
    # combine existing colnames
    cnames = vcat(ta1.colnames, ta2.colnames)
    # check if kwarg to over-ride simple vcat and then if colnames is valid length
    size(col_names,1) == 1 ? cnames = cnames :       # kwarg not supplied
    size(col_names,1) == size(vals,2) ? cnames = col_names : error("col_names supplied is not correct size")
    # put it all together
    TimeArray(tstamp, vals, cnames)
end

# part of merge2 method
function overlaps(t1, t2)
    i = j = 1
    idx1 = Int[]
    idx2 = Int[]
    while i < length(t1) + 1 && j < length(t2) + 1
        if t1[i] > t2[j]
            j += 1
        elseif t1[i] < t2[j]
            i += 1
        else
            push!(idx1, i)
            push!(idx2, j)
            i += 1
            j += 1
        end
    end
    (idx1, idx2)        
end

# thanks Tom Short @tshort for this implementation

function merge2{T}(ta1::TimeArray{T}, ta2::TimeArray{T}; col_names=[""])
    # obtain unique indexes of when dates match
    idx1, idx2 = overlaps(ta1.timestamp, ta2.timestamp)
    # obtain shared timestamp
    #tstamp = intersect(ta1.timestamp, ta2.timestamp)
    tstamp = ta1[idx1].timestamp
    # retrieve values that match the Int array matching dates
    vals1  = ta1[idx1].values
    vals2  = ta2[idx2].values
    # combine the values arrays
    vals   = hcat(vals1,vals2)
    # combine existing colnames
    cnames = vcat(ta1.colnames, ta2.colnames)
    # check if kwarg to over-ride simple vcat and then if colnames is valid length
    size(col_names,1) == 1 ? cnames = cnames :       # kwarg not supplied
    size(col_names,1) == size(vals,2) ? cnames = col_names : error("col_names supplied is not correct size")
    # put it all together
    TimeArray(tstamp, vals, cnames)
end

# collapse ######################

function collapse{T,N}(ta::TimeArray{T,N}, f::Function; period::Function=week)
  
  w = [period(ta.timestamp[t]) for t in 1:length(ta)] # get weekly id from entire array
  z = Int[]; j = 1
  for i=1:length(ta) - 1 # create unique period ID array
    if w[i] != w[i+1]
      push!(z, j)
      j = j+1
    else
      push!(z,j)
    end         
  end
  
  # account for last row
  w[length(ta)]  ==  w[length(ta)-1] ? # is the last row the same period as 2nd to last row?
  push!(z, z[length(z)]) :  
  push!(z, z[length(z)] + 1)  
 
  # pre-allocate timestamp and value arrays
  tstamps = [(Date(1,1,1):Year(1):Date(maximum(z),1,1));]
  vals    = zeros(maximum(z)) # number of unique periods
  #replace their values except for the last row 
  for i = 1:maximum(z)-1  # iterate over period ID groupings
    temp       = ta[findfirst(z .== i):findfirst(z .== i+1)-1] # period's worth that will be squished
    tstamps[i] = temp[length(temp)].timestamp[1]
    vals[i]    = f(temp.values)
  end
  # and once again account for the last temp that isn't looped on above
  lasttemp = ta[findfirst(z .== maximum(z)):length(ta)]
  lasttempindex = lasttemp[length(lasttemp)].timestamp
  lasttempvalue = f(ta.values)
  
  # complete the tstamp and vals arrays with the last value
  tstamps[length(tstamps)] = lasttempindex[1]
  vals[length(vals)]       = lasttempvalue

  TimeArray(tstamps, vals, ta.colnames, ta.meta)
end
