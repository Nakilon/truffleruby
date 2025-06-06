/**********************************************************************

  node.c - ruby node tree

  $Author: mame $
  created at: 09/12/06 21:23:44 JST

  Copyright (C) 2009 Yusuke Endoh

**********************************************************************/

#ifdef UNIVERSAL_PARSER

#include <stddef.h>
#include "node.h"
#include "rubyparser.h"
#include "internal/parse.h"
#define T_NODE 0x1b

#else

#include "internal.h"
#include "internal/compilers.h"
#include "internal/gc.h"
#include "internal/hash.h"
#include "internal/static_assert.h"
#include "internal/variable.h"
#include "ruby/ruby.h"
#include "vm_core.h"

#endif

#define NODE_BUF_DEFAULT_SIZE (sizeof(struct RNode) * 16)

static void
init_node_buffer_elem(node_buffer_elem_t *nbe, size_t allocated, void *xmalloc(size_t))
{
    nbe->allocated = allocated;
    nbe->used = 0;
    nbe->len = 0;
    nbe->nodes = xmalloc(allocated / sizeof(struct RNode) * sizeof(struct RNode *)); /* All node requires at least RNode */
}

static void
init_node_buffer_list(node_buffer_list_t * nb, node_buffer_elem_t *head, void *xmalloc(size_t))
{
    init_node_buffer_elem(head, NODE_BUF_DEFAULT_SIZE, xmalloc);
    nb->head = nb->last = head;
    nb->head->next = NULL;
}

#ifdef UNIVERSAL_PARSER
#define ruby_xmalloc config->malloc
#define Qnil config->qnil
#endif

#ifdef UNIVERSAL_PARSER
static node_buffer_t *
rb_node_buffer_new(rb_parser_config_t *config)
#else
static node_buffer_t *
rb_node_buffer_new(void)
#endif
{
    const size_t bucket_size = offsetof(node_buffer_elem_t, buf) + NODE_BUF_DEFAULT_SIZE;
    const size_t alloc_size = sizeof(node_buffer_t) + (bucket_size * 2);
    STATIC_ASSERT(
        integer_overflow,
        offsetof(node_buffer_elem_t, buf) + NODE_BUF_DEFAULT_SIZE
        > sizeof(node_buffer_t) + 2 * sizeof(node_buffer_elem_t));
    node_buffer_t *nb = ruby_xmalloc(alloc_size);
    init_node_buffer_list(&nb->unmarkable, (node_buffer_elem_t*)&nb[1], ruby_xmalloc);
    init_node_buffer_list(&nb->markable, (node_buffer_elem_t*)((size_t)nb->unmarkable.head + bucket_size), ruby_xmalloc);
    nb->local_tables = 0;
    nb->mark_hash = Qnil;
    nb->tokens = Qnil;
#ifdef UNIVERSAL_PARSER
    nb->config = config;
#endif
    return nb;
}

#ifdef UNIVERSAL_PARSER
#undef ruby_xmalloc
#define ruby_xmalloc ast->node_buffer->config->malloc
#undef xfree
#define xfree ast->node_buffer->config->free
#define rb_ident_hash_new ast->node_buffer->config->ident_hash_new
#define rb_xmalloc_mul_add ast->node_buffer->config->xmalloc_mul_add
#define ruby_xrealloc(var,size) (ast->node_buffer->config->realloc_n((void *)var, 1, size))
#define rb_gc_mark ast->node_buffer->config->gc_mark
#define rb_gc_location ast->node_buffer->config->gc_location
#define rb_gc_mark_movable ast->node_buffer->config->gc_mark_movable
#undef Qnil
#define Qnil ast->node_buffer->config->qnil
#define Qtrue ast->node_buffer->config->qtrue
#define NIL_P ast->node_buffer->config->nil_p
#define rb_hash_aset ast->node_buffer->config->hash_aset
#define rb_hash_delete ast->node_buffer->config->hash_delete
#define RB_OBJ_WRITE(old, slot, young) ast->node_buffer->config->obj_write((VALUE)(old), (VALUE *)(slot), (VALUE)(young))
#endif

typedef void node_itr_t(rb_ast_t *ast, void *ctx, NODE *node);
static void iterate_node_values(rb_ast_t *ast, node_buffer_list_t *nb, node_itr_t * func, void *ctx);

/* Setup NODE structure.
 * NODE is not an object managed by GC, but it imitates an object
 * so that it can work with `RB_TYPE_P(obj, T_NODE)`.
 * This dirty hack is needed because Ripper jumbles NODEs and other type
 * objects.
 */
void
rb_node_init(NODE *n, enum node_type type)
{
    RNODE(n)->flags = T_NODE;
    nd_init_type(RNODE(n), type);
    RNODE(n)->nd_loc.beg_pos.lineno = 0;
    RNODE(n)->nd_loc.beg_pos.column = 0;
    RNODE(n)->nd_loc.end_pos.lineno = 0;
    RNODE(n)->nd_loc.end_pos.column = 0;
    RNODE(n)->node_id = -1;
}

const char *
rb_node_name(int node)
{
    switch (node) {
#include "node_name.inc"
      default:
        return 0;
    }
}

#ifdef UNIVERSAL_PARSER
const char *
ruby_node_name(int node)
{
    return rb_node_name(node);
}
#else
const char *
ruby_node_name(int node)
{
    const char *name = rb_node_name(node);

    if (!name) rb_bug("unknown node: %d", node);
    return name;
}
#endif

static void
node_buffer_list_free(rb_ast_t *ast, node_buffer_list_t * nb)
{
    node_buffer_elem_t *nbe = nb->head;
    while (nbe != nb->last) {
        void *buf = nbe;
        xfree(nbe->nodes);
        nbe = nbe->next;
        xfree(buf);
    }

    /* The last node_buffer_elem_t is allocated in the node_buffer_t, so we
     * only need to free the nodes. */
    xfree(nbe->nodes);
}

struct rb_ast_local_table_link {
    struct rb_ast_local_table_link *next;
    // struct rb_ast_id_table {
    int size;
    ID ids[FLEX_ARY_LEN];
    // }
};

static void
free_ast_value(rb_ast_t *ast, void *ctx, NODE *node)
{
    switch (nd_type(node)) {
      default:
        break;
    }
}

static void
rb_node_buffer_free(rb_ast_t *ast, node_buffer_t *nb)
{
    iterate_node_values(ast, &nb->unmarkable, free_ast_value, NULL);
    node_buffer_list_free(ast, &nb->unmarkable);
    node_buffer_list_free(ast, &nb->markable);
    struct rb_ast_local_table_link *local_table = nb->local_tables;
    while (local_table) {
        struct rb_ast_local_table_link *next_table = local_table->next;
        xfree(local_table);
        local_table = next_table;
    }
    xfree(nb);
}

#define buf_add_offset(nbe, offset) ((char *)(nbe->buf) + (offset))

static NODE *
ast_newnode_in_bucket(rb_ast_t *ast, node_buffer_list_t *nb, size_t size, size_t alignment)
{
    size_t padding;
    NODE *ptr;

    padding = alignment - (size_t)buf_add_offset(nb->head, nb->head->used) % alignment;
    padding = padding == alignment ? 0 : padding;

    if (nb->head->used + size + padding > nb->head->allocated) {
        size_t n = nb->head->allocated * 2;
        node_buffer_elem_t *nbe;
        nbe = rb_xmalloc_mul_add(n, sizeof(char *), offsetof(node_buffer_elem_t, buf));
        init_node_buffer_elem(nbe, n, ruby_xmalloc);
        nbe->next = nb->head;
        nb->head = nbe;
        padding = 0; /* malloc returns aligned address then no need to add padding */
    }

    ptr = (NODE *)buf_add_offset(nb->head, nb->head->used + padding);
    nb->head->used += (size + padding);
    nb->head->nodes[nb->head->len++] = ptr;
    return ptr;
}

RBIMPL_ATTR_PURE()
static bool
nodetype_markable_p(enum node_type type)
{
    switch (type) {
      case NODE_MATCH:
      case NODE_LIT:
      case NODE_STR:
      case NODE_XSTR:
      case NODE_DSTR:
      case NODE_DXSTR:
      case NODE_DREGX:
      case NODE_DSYM:
        return true;
      default:
        return false;
    }
}

NODE *
rb_ast_newnode(rb_ast_t *ast, enum node_type type, size_t size, size_t alignment)
{
    node_buffer_t *nb = ast->node_buffer;
    node_buffer_list_t *bucket =
        (nodetype_markable_p(type) ? &nb->markable : &nb->unmarkable);
    return ast_newnode_in_bucket(ast, bucket, size, alignment);
}

#if RUBY_DEBUG
void
rb_ast_node_type_change(NODE *n, enum node_type type)
{
    enum node_type old_type = nd_type(n);
    if (nodetype_markable_p(old_type) != nodetype_markable_p(type)) {
        rb_bug("node type changed: %s -> %s",
               ruby_node_name(old_type), ruby_node_name(type));
    }
}
#endif

rb_ast_id_table_t *
rb_ast_new_local_table(rb_ast_t *ast, int size)
{
    size_t alloc_size = sizeof(struct rb_ast_local_table_link) + size * sizeof(ID);
    struct rb_ast_local_table_link *link = ruby_xmalloc(alloc_size);
    link->next = ast->node_buffer->local_tables;
    ast->node_buffer->local_tables = link;
    link->size = size;

    return (rb_ast_id_table_t *) &link->size;
}

rb_ast_id_table_t *
rb_ast_resize_latest_local_table(rb_ast_t *ast, int size)
{
    struct rb_ast_local_table_link *link = ast->node_buffer->local_tables;
    size_t alloc_size = sizeof(struct rb_ast_local_table_link) + size * sizeof(ID);
    link = ruby_xrealloc(link, alloc_size);
    ast->node_buffer->local_tables = link;
    link->size = size;

    return (rb_ast_id_table_t *) &link->size;
}

void
rb_ast_delete_node(rb_ast_t *ast, NODE *n)
{
    (void)ast;
    (void)n;
    /* should we implement freelist? */
}

#ifdef UNIVERSAL_PARSER
rb_ast_t *
rb_ast_new(rb_parser_config_t *config)
{
    node_buffer_t *nb = rb_node_buffer_new(config);
    config->counter++;
    return config->ast_new((VALUE)nb);
}
#else
rb_ast_t *
rb_ast_new(void)
{
    node_buffer_t *nb = rb_node_buffer_new();
#ifdef TRUFFLERUBY
    rb_ast_t *ast = xmalloc(sizeof(rb_ast_t));
    ast->node_buffer = nb;
#else
    rb_ast_t *ast = (rb_ast_t *)rb_imemo_new(imemo_ast, 0, 0, 0, (VALUE)nb);
#endif
    return ast;
}
#endif

static void
iterate_buffer_elements(rb_ast_t *ast, node_buffer_elem_t *nbe, long len, node_itr_t *func, void *ctx)
{
    long cursor;
    for (cursor = 0; cursor < len; cursor++) {
        func(ast, ctx, nbe->nodes[cursor]);
    }
}

static void
iterate_node_values(rb_ast_t *ast, node_buffer_list_t *nb, node_itr_t * func, void *ctx)
{
    node_buffer_elem_t *nbe = nb->head;

    while (nbe) {
        iterate_buffer_elements(ast, nbe, nbe->len, func, ctx);
        nbe = nbe->next;
    }
}

static void
mark_ast_value(rb_ast_t *ast, void *ctx, NODE *node)
{
#ifdef UNIVERSAL_PARSER
    bug_report_func rb_bug = ast->node_buffer->config->bug;
#endif

    switch (nd_type(node)) {
      case NODE_MATCH:
      case NODE_LIT:
      case NODE_STR:
      case NODE_XSTR:
      case NODE_DSTR:
      case NODE_DXSTR:
      case NODE_DREGX:
      case NODE_DSYM:
        rb_gc_mark_movable(RNODE_LIT(node)->nd_lit);
        break;
      default:
        rb_bug("unreachable node %s", ruby_node_name(nd_type(node)));
    }
}

static void
update_ast_value(rb_ast_t *ast, void *ctx, NODE *node)
{
#ifdef UNIVERSAL_PARSER
    bug_report_func rb_bug = ast->node_buffer->config->bug;
#endif

    switch (nd_type(node)) {
      case NODE_MATCH:
      case NODE_LIT:
      case NODE_STR:
      case NODE_XSTR:
      case NODE_DSTR:
      case NODE_DXSTR:
      case NODE_DREGX:
      case NODE_DSYM:
        RNODE_LIT(node)->nd_lit = rb_gc_location(RNODE_LIT(node)->nd_lit);
        break;
      default:
        rb_bug("unreachable");
    }
}

void
rb_ast_update_references(rb_ast_t *ast)
{
    if (ast->node_buffer) {
        node_buffer_t *nb = ast->node_buffer;

        iterate_node_values(ast, &nb->markable, update_ast_value, NULL);
    }
}

void
rb_ast_mark(rb_ast_t *ast)
{
    if (ast->node_buffer) {
        rb_gc_mark(ast->node_buffer->mark_hash);
        rb_gc_mark(ast->node_buffer->tokens);
        node_buffer_t *nb = ast->node_buffer;
        iterate_node_values(ast, &nb->markable, mark_ast_value, NULL);
        if (ast->body.script_lines) rb_gc_mark(ast->body.script_lines);
    }
}

void
rb_ast_free(rb_ast_t *ast)
{
    if (ast->node_buffer) {
#ifdef UNIVERSAL_PARSER
        rb_parser_config_t *config = ast->node_buffer->config;
#endif

        rb_node_buffer_free(ast, ast->node_buffer);
        ast->node_buffer = 0;
#ifdef UNIVERSAL_PARSER
        config->counter--;
        if (config->counter <= 0) {
            rb_ruby_parser_config_free(config);
        }
#endif
    }
}

static size_t
buffer_list_size(node_buffer_list_t *nb)
{
    size_t size = 0;
    node_buffer_elem_t *nbe = nb->head;
    while (nbe != nb->last) {
        size += offsetof(node_buffer_elem_t, buf) + nbe->used;
        nbe = nbe->next;
    }
    return size;
}

size_t
rb_ast_memsize(const rb_ast_t *ast)
{
    size_t size = 0;
    node_buffer_t *nb = ast->node_buffer;

    if (nb) {
        size += sizeof(node_buffer_t);
        size += buffer_list_size(&nb->unmarkable);
        size += buffer_list_size(&nb->markable);
    }
    return size;
}

void
rb_ast_dispose(rb_ast_t *ast)
{
    rb_ast_free(ast);
}

void
rb_ast_add_mark_object(rb_ast_t *ast, VALUE obj)
{
    if (NIL_P(ast->node_buffer->mark_hash)) {
        RB_OBJ_WRITE(ast, &ast->node_buffer->mark_hash, rb_ident_hash_new());
    }
    rb_hash_aset(ast->node_buffer->mark_hash, obj, Qtrue);
}

void
rb_ast_delete_mark_object(rb_ast_t *ast, VALUE obj)
{
    if (NIL_P(ast->node_buffer->mark_hash)) return;
    rb_hash_delete(ast->node_buffer->mark_hash, obj);
}

VALUE
rb_ast_tokens(rb_ast_t *ast)
{
    return ast->node_buffer->tokens;
}

void
rb_ast_set_tokens(rb_ast_t *ast, VALUE tokens)
{
    RB_OBJ_WRITE(ast, &ast->node_buffer->tokens, tokens);
}

VALUE
rb_node_set_type(NODE *n, enum node_type t)
{
#if RUBY_DEBUG
    rb_ast_node_type_change(n, t);
#endif
    return nd_init_type(n, t);
}
