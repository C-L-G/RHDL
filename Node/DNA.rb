
## Atom Seq Build
block_name_seq = SingleBondSeq.new(name:"ID",re:/\A\w+\s/)
one_line_comment_seq = SingleBondSeq.new(name:"one line comment",re:/\A\/\/.*?\n/)
mul_lines_comment_seq = SingleBondSeq.new(name:"mul lines commment",re:/\A\/\*.*?\*\//m)
symbol_seq = SingleBondSeq.new(name:"symbol",re:/\A(?:\*\*|\*|%|\+|-|\/|==|!=)/,discontinue:true)
pre_symbol_seq = SingleBondSeq.new(name:"pre_symbol",re:/\A(?:~)/,discontinue:true)
comma_seq = SingleBondSeq.new(name:"comma",re:/\A,/,discontinue:true)

def define_frame_edge(name,begin_seqs_hash_array:[],end_seqs_hash_array:[])
    gen_seq = lambda do |flag,hash_item|
     if hash_item.is_a?  Hash
         SingleBondSeq.new(name:(name.to_s+" #{flag} "+hash_item[:name],re:hash_item[:re],force:hash_item[:force])
     elsif hash_item.is_a? BaseSeq
         hash_item
     else
         raise 'NO A valid Value'
     end
    end
    head_seqs = begin_seqs_hash_array.each do |hash_item|
     gen_seq.call("begin",hash_item)
    end
    end_seqs = end_seqs_hash_array.each do |hash_item|
      gen_seq.call("end",hash_item)
    end
    new_class = Class.new(BasePool)
    new_class.class_variable_set("name",name.to_s)
    new_class.class_variable_set("@@begin_seq_pools",head_seqs)
    new_class.class_variable_set("@@end_seq_pools",end_seqs)
    instance_variable_set(name.to_s+'_poolclass',new_class)
    seq = PoolBondSeq.new(name:name,pool_class:new_class,force:nil)
    instance_variable_set(name.to_s+'_seq',seq)
end

def define_generice_block(*args)
    args.each do |item|
        define_frame_edge   item,
                            begin_seqs_hash_array:[
                                {:name=>"head",     re:Regexp.new("\\A#{item.to_s}\\s"),    force:true  },
                                {:name=>"id",       re:/\A\w+\s/,                force:true  },
                                {:name=>"Enter"     re:/\n/,                     force:true  }
                            ],
                            end_seqs_hash_array:[
                                {:name=>"head",     re:Regexp.new("\\Aend#{item.to_s}\\s"), force:true    },
                                {:name=>":",        re:/\A:\s*\w+/,   force:nil     },
                                {:name=>"Enter"     re:/\n/,          force:true    }
                            ]
    end
end
### define frame ###
define_generice_block :module,:interface,:localparam,:parameter,:always_c,:always_f
define_frame_edge   "parenthese",
                    begin_seqs_hash_array:[
                        {:name=>"left",     re:/\A\(/, force:true  }
                    ],
                    end_seqs_hash_array:[
                        {:name=>"right",    re:/\A\)/, force:true  }
                    ]

define_frame_edge   "square_brackets",
                    begin_seqs_hash_array:[
                        {:name=>"left",     re:/\A\[/, force:true  }
                    ],
                    end_seqs_hash_array:[
                        {:name=>"right",    re:/\A\]/, force:true  }
                    ]

define_frame_edge   "brace",
                    begin_seqs_hash_array:[
                        {:name=>"left",     re:/\A\{/, force:true  }
                    ],
                    end_seqs_hash_array:[
                        {:name=>"right",    re:/\A\}/, force:true  }
                    ]

variable_poolclass = Class.new(BasePool)
variable_poolclass.class_variable_set("@@begin_seq_pools",[block_name_seq,square_brackets_seq])
variable_seq = PoolBondSeq.new(name:"Variable",variable_poolclass,discontinue:true)
