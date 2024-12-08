workerpool = require 'workerpool'

{ kernWorker } = require './lib/kernalgorithm'

workerpool.worker { kernWorker }
